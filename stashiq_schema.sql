-- 1) Create or use the database
CREATE DATABASE IF NOT EXISTS stashiq_db;
USE stashiq_db;

-- 2) Drop existing tables if they exist (optional if re-running)
DROP TABLE IF EXISTS consumption_logs;
DROP TABLE IF EXISTS recipe_ingredients;
DROP TABLE IF EXISTS recipes;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS inventory;
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

-- 6) UNITS TABLE (lookup table for valid measurement units, e.g., "pcs", "cup", "oz", "can")
CREATE TABLE units (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  UNIQUE KEY (name)
) ENGINE=InnoDB;

-- 7) BARCODES TABLE (lookup table for default product info)
CREATE TABLE barcodes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  barcode_value VARCHAR(50) NOT NULL,
  default_name VARCHAR(150) NOT NULL,
  default_unit_id INT NOT NULL,  
  brand VARCHAR(150),
  UNIQUE KEY (barcode_value),
  CONSTRAINT fk_barcodes_unit
    FOREIGN KEY (default_unit_id) REFERENCES units(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 8) ITEMS TABLE
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

-- 9) INVENTORY TABLE
CREATE TABLE inventory (
  id INT AUTO_INCREMENT PRIMARY KEY,
  barcode_id INT NOT NULL,
  shelf_id INT NOT NULL,
  quantity DECIMAL(10,2) DEFAULT 0.00,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_inventory_barcode
    FOREIGN KEY (barcode_id) REFERENCES barcodes(id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_inventory_shelf
    FOREIGN KEY (shelf_id) REFERENCES shelves(id)
    ON DELETE CASCADE,
  UNIQUE KEY (barcode_id, shelf_id)
) ENGINE=InnoDB;

-- 10) RECIPES TABLE
CREATE TABLE recipes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  instructions TEXT
) ENGINE=InnoDB;

-- 11) RECIPE_INGREDIENTS TABLE (expanded to handle multiple ways of specifying an item)
CREATE TABLE recipe_ingredients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  recipe_id INT NOT NULL,
  
  -- Option A: Link to a barcode if you want a specific product
  barcode_id INT NULL,

  -- Option B: Free-text name if there's no barcode or it's flexible
  item_name VARCHAR(150) NOT NULL, 

  -- How much of it does the recipe call for (structured)
  quantity_needed DECIMAL(10,2) DEFAULT 1.0,

  -- Link to a standard unit if relevant (e.g., “cup”, “oz”, “can”)
  unit_id INT NULL,

  -- Optional free-form text describing packaging size, brand, or format (e.g., “8oz can”)
  package_description VARCHAR(150),

  CONSTRAINT fk_recipe_ingredients_recipe
    FOREIGN KEY (recipe_id) REFERENCES recipes(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_recipe_ingredients_barcode
    FOREIGN KEY (barcode_id) REFERENCES barcodes(id)
    ON DELETE SET NULL,
  CONSTRAINT fk_recipe_ingredients_unit
    FOREIGN KEY (unit_id) REFERENCES units(id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- 12) CONSUMPTION_LOGS TABLE
CREATE TABLE consumption_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  item_id INT NOT NULL,
  quantity_used DECIMAL(10,2) NOT NULL,
  used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  action_type ENUM('USED','WASTED') NOT NULL,
  CONSTRAINT fk_consumption_logs_item
    FOREIGN KEY (item_id) REFERENCES items(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- Confirmation
SELECT 'StashIQ DB with flexible recipe ingredients created successfully!' AS Status;
