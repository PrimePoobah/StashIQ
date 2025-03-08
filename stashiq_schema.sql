-- Create the database if it doesn't exist, then switch to it
CREATE DATABASE IF NOT EXISTS stashiq_db;
USE stashiq_db;

-- Drop tables if they exist (optional cleanup if re-running script)
DROP TABLE IF EXISTS consumption_logs;
DROP TABLE IF EXISTS recipe_ingredients;
DROP TABLE IF EXISTS recipes;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS shelves;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS users;

-- 1) USERS TABLE
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  email VARCHAR(100),
  UNIQUE KEY (username)
) ENGINE=InnoDB;

-- 2) LOCATIONS TABLE
CREATE TABLE locations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT
) ENGINE=InnoDB;

-- 3) SHELVES TABLE
CREATE TABLE shelves (
  id INT AUTO_INCREMENT PRIMARY KEY,
  location_id INT NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  CONSTRAINT fk_shelves_location
    FOREIGN KEY (location_id) REFERENCES locations(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- 4) ITEMS TABLE
CREATE TABLE items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  shelf_id INT NOT NULL,
  name VARCHAR(150) NOT NULL,
  quantity DECIMAL(10,2) DEFAULT 1.0,
  unit VARCHAR(50) DEFAULT 'pcs',
  expiry_date DATE,
  purchase_date DATE,
  cost DECIMAL(10,2),
  barcode VARCHAR(50),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_items_shelf
    FOREIGN KEY (shelf_id) REFERENCES shelves(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5) RECIPES TABLE
CREATE TABLE recipes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  instructions TEXT
) ENGINE=InnoDB;

-- 6) RECIPE_INGREDIENTS TABLE
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

-- 7) CONSUMPTION_LOGS TABLE
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
SELECT 'StashIQ DB and tables created successfully!' AS Status;
