-- PBMS Odoo eligibility SQL uses g2p_register_farmer; Farmer Registry table is g2p_register_farmers.
-- Table is created later by staff-api migrate — only create the view when it exists.
\c farmer_registry_db
DO $$
BEGIN
  IF to_regclass('public.g2p_register_farmers') IS NOT NULL THEN
    EXECUTE 'CREATE OR REPLACE VIEW g2p_register_farmer AS SELECT * FROM g2p_register_farmers';
  END IF;
END
$$;
