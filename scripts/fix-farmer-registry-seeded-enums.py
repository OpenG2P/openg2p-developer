#!/usr/bin/env python3
"""Align seeded farmer registry rows with current Pydantic enum values.

Covers live register tables, history twins, intake-form twins, and
change-request payloads so approve / history / webhook paths stay consistent.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import psycopg2
from psycopg2.extras import Json

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from farmer_seed_enum_normalization import (  # noqa: E402
    LOOKUP_VALUE_FIELDS,
    SOURCE_OF_INCOME_LEGACY,
    VALID_SOURCE_OF_INCOME,
    lookup_value_id_map,
    normalize_json_tree_if_changed,
    normalize_lookup_value,
    normalize_source_of_income_fields,
)

FARMER_SOI_TABLES = (
    "g2p_register_farmers",
    "g2p_register_history_farmers",
    "g2p_intake_form_farmers",
)

LOOKUP_TABLE_FIELDS: dict[str, list[str]] = {
    "g2p_register_livestocks": ["livestock_type", "breed"],
    "g2p_register_crops": ["commodity", "season"],
    "g2p_register_lands": ["means_of_acquisition", "soil_fertility"],
    "g2p_register_farm_inputs": ["water_source"],
    "g2p_register_history_livestocks": ["livestock_type", "breed"],
    "g2p_register_history_crops": ["commodity", "season"],
    "g2p_register_history_lands": ["means_of_acquisition", "soil_fertility"],
    "g2p_register_history_farm_inputs": ["water_source"],
    "g2p_intake_form_livestocks": ["livestock_type", "breed"],
    "g2p_intake_form_crops": ["commodity", "season"],
    "g2p_intake_form_lands": ["means_of_acquisition", "soil_fertility"],
    "g2p_intake_form_farm_inputs": ["water_source"],
}


def _connect() -> psycopg2.extensions.connection:
    return psycopg2.connect(
        host=os.environ["PGHOST"],
        port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ["PGDATABASE"],
        user=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
    )


def _table_exists(cur, table: str) -> bool:
    cur.execute(
        """
        SELECT EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'public' AND table_name = %s
        )
        """,
        (table,),
    )
    return bool(cur.fetchone()[0])


def _columns(cur, table: str) -> set[str]:
    cur.execute(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (table,),
    )
    return {row[0] for row in cur.fetchall()}


def _fix_source_of_income_table(cur, table: str) -> int:
    if not _table_exists(cur, table):
        return 0
    cols = _columns(cur, table)
    if "source_of_income" not in cols:
        return 0

    id_col = "history_record_id" if "history_record_id" in cols else "internal_record_id"
    has_other = "source_of_income_other" in cols
    select_cols = f'"{id_col}", source_of_income'
    if has_other:
        select_cols += ", source_of_income_other"

    legacy_values = tuple(SOURCE_OF_INCOME_LEGACY.keys())
    cur.execute(
        f"""
        SELECT {select_cols}
        FROM "public"."{table}"
        WHERE source_of_income = ANY(%s)
           OR (
             source_of_income IS NOT NULL
             AND source_of_income NOT IN (
               'CROP_PRODUCTION', 'LIVESTOCK_PRODUCTION',
               'GOVERNMENT_NGO_SUPPORT', 'OTHERS'
             )
           )
        """,
        (list(legacy_values),),
    )
    rows = cur.fetchall()
    updated = 0
    for row in rows:
        record_id = row[0]
        source_of_income = row[1]
        source_of_income_other = row[2] if has_other else None
        normalized = normalize_source_of_income_fields(
            {
                "source_of_income": source_of_income,
                "source_of_income_other": source_of_income_other,
            }
        )
        if has_other:
            cur.execute(
                f"""
                UPDATE "public"."{table}"
                SET source_of_income = %s, source_of_income_other = %s
                WHERE "{id_col}" = %s
                """,
                (
                    normalized.get("source_of_income"),
                    normalized.get("source_of_income_other"),
                    record_id,
                ),
            )
        else:
            cur.execute(
                f"""
                UPDATE "public"."{table}"
                SET source_of_income = %s
                WHERE "{id_col}" = %s
                """,
                (normalized.get("source_of_income"), record_id),
            )
        updated += 1
    return updated


def _fix_lookup_columns(cur) -> int:
    value_ids = tuple(lookup_value_id_map().keys())
    if not value_ids:
        return 0

    updated = 0
    for table, fields in LOOKUP_TABLE_FIELDS.items():
        if not _table_exists(cur, table):
            continue
        cols = _columns(cur, table)
        for field in fields:
            if field not in LOOKUP_VALUE_FIELDS or field not in cols:
                continue
            cur.execute(
                f"""
                SELECT "{field}", COUNT(*)
                FROM "public"."{table}"
                WHERE "{field}" = ANY(%s)
                GROUP BY 1
                """,
                (list(value_ids),),
            )
            for raw_value, count in cur.fetchall():
                mapped = normalize_lookup_value(raw_value)
                if mapped == raw_value:
                    continue
                cur.execute(
                    f"""
                    UPDATE "public"."{table}"
                    SET "{field}" = %s
                    WHERE "{field}" = %s
                    """,
                    (mapped, raw_value),
                )
                updated += count
    return updated


def _fix_change_request_payloads(cur) -> int:
    if not _table_exists(cur, "g2p_register_change_request_payloads"):
        return 0

    cur.execute(
        """
        SELECT change_request_id, change_payload
        FROM "public"."g2p_register_change_request_payloads"
        """
    )
    updated = 0
    for change_request_id, payload in cur.fetchall():
        if payload is None:
            continue
        if isinstance(payload, str):
            payload = json.loads(payload)
        normalized, changed = normalize_json_tree_if_changed(payload)
        if not changed:
            continue
        cur.execute(
            """
            UPDATE "public"."g2p_register_change_request_payloads"
            SET change_payload = %s
            WHERE change_request_id = %s
            """,
            (Json(normalized), change_request_id),
        )
        updated += 1
    return updated


def main() -> None:
    conn = _connect()
    try:
        with conn:
            with conn.cursor() as cur:
                soi_updates = 0
                for table in FARMER_SOI_TABLES:
                    soi_updates += _fix_source_of_income_table(cur, table)
                lookup_updates = _fix_lookup_columns(cur)
                payload_updates = _fix_change_request_payloads(cur)
        print(
            "[fix-farmer-enums] Updated "
            f"{soi_updates} source_of_income row(s), "
            f"{lookup_updates} lookup column value(s), "
            f"{payload_updates} change-request payload(s)"
        )
        # Keep validators happy when importing this module's constants elsewhere.
        _ = VALID_SOURCE_OF_INCOME
    finally:
        conn.close()


if __name__ == "__main__":
    main()
