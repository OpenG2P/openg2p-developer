#!/usr/bin/env python3
"""Backfill g2p_register_history_* from live seeded register rows.

Sample seed marks farmers ACTIVE with last_approved_* but never writes history.
Version-history UI and CR flows expect at least one history snapshot per record.
This creates an idempotent baseline history row (change_request_source=STAFF_PORTAL)
for every live row that still has no history.
"""

from __future__ import annotations

import os

import psycopg2

# (live_table, history_table, tab_id, section_id, is_primary_section)
HISTORY_SPECS: list[tuple[str, str, str, str, bool]] = [
    (
        "g2p_register_farmers",
        "g2p_register_history_farmers",
        "farmer_farmer_tab",
        "farmer_farmer_personal_identification_section_01",
        True,
    ),
    (
        "g2p_register_households",
        "g2p_register_history_households",
        "farmer_household_link_tab",
        "farmer_household_household_information_section_01",
        False,
    ),
    (
        "g2p_register_household_members",
        "g2p_register_history_household_members",
        "farmer_household_link_tab",
        "farmer_household_household_member_section_02",
        False,
    ),
    (
        "g2p_register_lands",
        "g2p_register_history_lands",
        "farmer_land_tab",
        "farmer_farm_farm_details_section_01",
        False,
    ),
    (
        "g2p_register_crops",
        "g2p_register_history_crops",
        "farmer_crop_tab",
        "farmer_crop_crop_details_section_01",
        False,
    ),
    (
        "g2p_register_livestocks",
        "g2p_register_history_livestocks",
        "farmer_livestock_tab",
        "farmer_livestock_livestock_details_section_01",
        False,
    ),
    (
        "g2p_register_farm_inputs",
        "g2p_register_history_farm_inputs",
        "farmer_farm_input_tab",
        "farmer_farm_input_farm_input_details_section_01",
        False,
    ),
    (
        "g2p_register_membership_details",
        "g2p_register_history_membership_details",
        "farmer_membership_tab",
        "farmer_membership_membership_details_01",
        False,
    ),
]


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


def _columns(cur, table: str) -> list[str]:
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        ORDER BY ordinal_position
        """,
        (table,),
    )
    return [row[0] for row in cur.fetchall()]


def _backfill_one(
    cur,
    live_table: str,
    history_table: str,
    tab_id: str,
    section_id: str,
    is_primary_section: bool,
) -> int:
    if not _table_exists(cur, live_table) or not _table_exists(cur, history_table):
        return 0

    live_cols = set(_columns(cur, live_table))
    history_cols = set(_columns(cur, history_table))

    # Domain columns shared by live + history (exclude live-only audit names).
    skip_live = {"search_text", "last_approved_at", "last_approved_by"}
    shared = sorted((live_cols & history_cols) - skip_live)

    insert_cols = [
        "history_record_id",
        "internal_record_id",
        "tab_id",
        "section_id",
        "change_request_id",
        "submission_id",
        "change_request_source",
        "is_primary_section",
    ]
    select_sql_parts = [
        "gen_random_uuid()::text",
        "live.internal_record_id",
        "%s",
        "%s",
        "NULL",
        "NULL",
        "%s",
        "%s",
    ]
    bind: list[object] = [tab_id, section_id, "STAFF_PORTAL", is_primary_section]

    for col in shared:
        if col in insert_cols:
            continue
        insert_cols.append(col)
        select_sql_parts.append(f'live."{col}"')

    if "approved_by" in history_cols and "approved_by" not in insert_cols:
        insert_cols.append("approved_by")
        if "last_approved_by" in live_cols:
            select_sql_parts.append("live.last_approved_by")
        elif "created_by" in live_cols:
            select_sql_parts.append("live.created_by")
        else:
            select_sql_parts.append("'seed'")

    if "approved_at" in history_cols and "approved_at" not in insert_cols:
        insert_cols.append("approved_at")
        if "last_approved_at" in live_cols:
            select_sql_parts.append("live.last_approved_at")
        elif "created_at" in live_cols:
            select_sql_parts.append("live.created_at")
        else:
            select_sql_parts.append("NOW()")

    if "created_by" in history_cols and "created_by" not in insert_cols:
        insert_cols.append("created_by")
        select_sql_parts.append(
            "live.created_by" if "created_by" in live_cols else "'seed'"
        )
    if "created_at" in history_cols and "created_at" not in insert_cols:
        insert_cols.append("created_at")
        select_sql_parts.append(
            "live.created_at" if "created_at" in live_cols else "NOW()"
        )

    insert_col_sql = ", ".join(f'"{c}"' for c in insert_cols)
    select_sql = ", ".join(select_sql_parts)

    sql = f"""
        INSERT INTO "public"."{history_table}" ({insert_col_sql})
        SELECT {select_sql}
        FROM "public"."{live_table}" AS live
        WHERE NOT EXISTS (
          SELECT 1 FROM "public"."{history_table}" AS hist
          WHERE hist.internal_record_id = live.internal_record_id
        )
    """
    cur.execute(sql, bind)
    return cur.rowcount


def main() -> None:
    conn = _connect()
    try:
        totals: list[tuple[str, int]] = []
        with conn:
            with conn.cursor() as cur:
                for live, history, tab_id, section_id, is_primary in HISTORY_SPECS:
                    count = _backfill_one(
                        cur, live, history, tab_id, section_id, is_primary
                    )
                    totals.append((history, count))
        print("[seed-farmer-history] Baseline history backfill:")
        for table, count in totals:
            print(f"  {table}: +{count}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
