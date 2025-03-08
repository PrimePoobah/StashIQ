-- 1) Create the database if it doesn't exist, then switch to it
CREATE DATABASE IF NOT EXISTS stashiq_db;
USE stashiq_db;

-- 2) Drop existing tables if they exist (optional cleanup if re-running script)
DROP TABLE IF EXISTS consumption_logs;
DROP TABLE IF EXISTS recipe_ingredients;
DROP TABLE IF EXISTS recipes;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS shelves;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS barcodes;
DROP TABLE IF EXISTS units;

-- 3) USERS TABLE (optional if single-user)
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(100),
  UNIQUE KEY (username)
) ENGINE=InnoDB;

-- 4) LOCATIONS TABLE
CREATE TABLE locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT
) ENGINE=InnoDB;

-- 5) SHELVES TABLE
CREATE TABLE shelves (
  id INT AUTO_INCREMENT PRIMARY KEY,
  location_id INT NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  CONSTRAINT fk_shelves_location
    FOREIGN KEY (location_id) REFERENCES locations(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6) UNITS TABLE (lookup table for valid measurement units)
CREATE TABLE units (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  UNIQUE KEY (name)
) ENGINE=InnoDB;

-- 7) BARCODES TABLE (lookup table for product defaults by barcode)
CREATE TABLE barcodes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  barcode_value VARCHAR(50) NOT NULL,
  default_name VARCHAR(150) NOT NULL,
  default_unit_id INT NOT NULL,  -- references 'units' table
  brand VARCHAR(150),
  UNIQUE KEY (barcode_value),
  CONSTRAINT fk_barcodes_unit
    FOREIGN KEY (default_unit_id) REFERENCES units(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 8) ITEMS TABLE
--    Now references 'barcode_id' (lookup) and 'unit_id' for this specific item's chosen unit
CREATE TABLE items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  shelf_id INT NOT NULL,
  barcode_id INT NULL,
  name VARCHAR(150) NOT NULL,
  quantity DECIMAL(10,2) DEFAULT 1.0,
  unit_id INT NOT NULL,
  expiry_date DATE,
  purchase_date DATE,
  cost DECIMAL(10,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_items_shelf
    FOREIGN KEY (shelf_id) REFERENCES shelves(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_items_barcode
    FOREIGN KEY (barcode_id) REFERENCES barcodes(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_items_unit
    FOREIGN KEY (unit_id) REFERENCES units(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 9) RECIPES TABLE
CREATE TABLE recipes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  instructions TEXT
) ENGINE=InnoDB;

-- 10) RECIPE_INGREDIENTS TABLE
CREATE TABLE recipe_ingredients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  recipe_id INT NOT NULL,
  item_name VARCHAR(150) NOT NULL,
  quantity_needed DECIMAL(10,2),
  unit VARCHAR(50),
  CONSTRAINT fk_recipe_ingredients_recipe
    FOREIGN KEY (recipe_id) REFERENCES recipes(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- 11) CONSUMPTION_LOGS TABLE
CREATE TABLE consumption_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  item_id INT NOT NULL,
  quantity_used DECIMAL(10,2) NOT NULL,
  used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_consumption_logs_item
    FOREIGN KEY (item_id) REFERENCES items(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- Confirmation message
SELECT 'StashIQ DB with barcodes, units, and references created successfully!' AS Status;
