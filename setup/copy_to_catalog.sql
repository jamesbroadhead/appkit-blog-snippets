-- Copy wanderbricks sample tables to your own catalog so you can
-- enable Change Data Feed and create synced tables from them.
-- Run with: databricks sql execute --warehouse-id $DATABRICKS_WAREHOUSE_ID -f setup/copy_to_catalog.sql

CREATE SCHEMA IF NOT EXISTS main.wanderbricks;

CREATE TABLE main.wanderbricks.bookings     AS SELECT * FROM samples.wanderbricks.bookings;
CREATE TABLE main.wanderbricks.users        AS SELECT * FROM samples.wanderbricks.users;
CREATE TABLE main.wanderbricks.properties   AS SELECT * FROM samples.wanderbricks.properties;
CREATE TABLE main.wanderbricks.destinations AS SELECT * FROM samples.wanderbricks.destinations;
