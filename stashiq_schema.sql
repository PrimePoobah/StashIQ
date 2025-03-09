-- =============================================================
-- 1) Create or use the database
-- =============================================================
CREATE DATABASE IF NOT EXISTS stashiq_db;
USE stashiq_db;

-- =============================================================
-- 2) Drop existing tables (optional if re-running)
-- =============================================================
DROP TABLE IF EXISTS recipes_audit;
DROP TABLE IF EXISTS users_audit;
DROP TABLE IF EXISTS items_audit;
DROP TABLE IF EXISTS consumption_logs;
DROP TABLE IF EXISTS consumption_actions;
DROP TABLE IF EXISTS recipe_tags;
DROP TABLE IF EXISTS item_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS recipe_ingredients;
DROP TABLE IF EXISTS recipes;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS currencies;
DROP TABLE IF EXISTS barcodes;
DROP TABLE IF EXISTS units;
DROP TABLE IF EXISTS shelves;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- =============================================================
-- 3) Create the Roles Table for managing user roles
-- =============================================================
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- =============================================================
-- 4) Insert Sample Roles with permission descriptions
-- =============================================================
INSERT INTO roles (name, description) VALUES
  ('ADMIN', 'Can edit everything—including user management (add, modify, delete users) and all item operations.'),
  ('STANDARD', 'Can log in and view, add, update, and consume items; cannot manage users.'),
  ('VIEWER', 'Read-only access: can view items and inventory without access to user management.');

-- =============================================================
-- 5) Create the Permissions Table for granular permissions
-- =============================================================
CREATE TABLE permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- =============================================================
-- 6) Insert Sample Permissions
-- =============================================================
INSERT INTO permissions (name, description) VALUES
  ('USER_CREATE', 'Create new users'),
  ('USER_UPDATE', 'Update existing users'),
  ('USER_DELETE', 'Delete users'),
  ('USER_VIEW', 'View user details'),
  ('ITEM_CREATE', 'Add new items'),
  ('ITEM_UPDATE', 'Update items'),
  ('ITEM_DELETE', 'Delete items'),
  ('ITEM_CONSUME', 'Consume items'),
  ('ITEM_VIEW', 'View items');

-- =============================================================
-- 7) Create the Role_Permissions Table to map roles to permissions
-- =============================================================
CREATE TABLE role_permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_id INT NOT NULL,
    permission_id INT NOT NULL,
    UNIQUE KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Map ADMIN (id=1) to all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM permissions;

-- =============================================================
-- 8) Create the Users Table with role_id, soft delete, and dynamic extra attributes
-- =============================================================
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role_id INT NOT NULL DEFAULT 2,  -- Defaults to STANDARD
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login DATETIME DEFAULT NULL,
    deleted_at DATETIME DEFAULT NULL,
    extra_attributes JSON DEFAULT NULL,
    UNIQUE KEY (username),
    INDEX (role_id),
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Insert default admin user (username: stashiq, password: inventory) using bcrypt.
-- (Replace the bcrypt hash with one generated securely for production.)
INSERT INTO users (username, password_hash, email, role_id)
VALUES ('stashiq', '$2b$12$DX6kXHnYzwjtPKkoIsNoQOZcNZ0LjL8klWdY8IyO71qHDniVf7O6S', 'admin@example.com', 1);

-- =============================================================
-- 9) Create the Locations Table
-- =============================================================
CREATE TABLE locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =============================================================
-- 10) Create the Shelves Table
-- =============================================================
CREATE TABLE shelves (
    id INT AUTO_INCREMENT PRIMARY KEY,
    location_id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (location_id),
    CONSTRAINT fk_shelves_location FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================
-- 11) Create the Units Table (lookup table for valid measurement units)
-- =============================================================
CREATE TABLE units (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- =============================================================
-- 12) Create the Barcodes Table (lookup table for default product info)
-- =============================================================
CREATE TABLE barcodes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    barcode_value VARCHAR(50) NOT NULL,
    default_name VARCHAR(150) NOT NULL,
    default_unit_id INT NOT NULL,
    brand VARCHAR(150),
    UNIQUE KEY (barcode_value),
    INDEX (default_unit_id),
    CONSTRAINT fk_barcodes_unit FOREIGN KEY (default_unit_id) REFERENCES units(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =============================================================
-- 13) Create the Currencies Table for global currency handling
-- =============================================================
CREATE TABLE currencies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code CHAR(3) NOT NULL UNIQUE,    -- ISO 4217 code (e.g., USD, EUR, JPY)
    name VARCHAR(50) NOT NULL,         -- Full currency name
    symbol VARCHAR(10),                -- Currency symbol (e.g., $, €, ¥)
    exchange_rate DECIMAL(10,6) DEFAULT 1.0  -- Relative to a base currency (e.g., USD)
) ENGINE=InnoDB;

INSERT INTO currencies (code, name, symbol, exchange_rate) VALUES
  ('CAD', 'Canadian Dollar', '$', 1.0),
  ('USD', 'United States Dollar', '$', 1.0),
  ('EUR', 'Euro', '€', 0.90),
  ('GBP', 'British Pound Sterling', '£', 0.78),
  ('JPY', 'Japanese Yen', '¥', 110.0);

-- =============================================================
-- 14) Create the Categories Table for items
-- =============================================================
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

INSERT INTO categories (name, description) VALUES
  ('Dairy', 'Milk, cheese, and other dairy products'),
  ('Produce', 'Fruits and vegetables'),
  ('Canned', 'Canned goods and preserved foods');

-- =============================================================
-- 15) Create the Items Table with auditing, soft delete, dynamic attributes, and currency reference
-- =============================================================
CREATE TABLE items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shelf_id INT NOT NULL,
    barcode_id INT DEFAULT NULL,
    category_id INT DEFAULT NULL,
    name VARCHAR(150) NOT NULL,
    quantity DECIMAL(10,2) DEFAULT 1.0,
    unit_id INT NOT NULL,
    expiry_date DATE,
    purchase_date DATE,
    cost DECIMAL(10,2),
    currency_id INT NOT NULL DEFAULT 1,
    extra_attributes JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT DEFAULT NULL,
    updated_by INT DEFAULT NULL,
    deleted_at DATETIME DEFAULT NULL,
    CONSTRAINT fk_items_shelf FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE,
    CONSTRAINT fk_items_barcode FOREIGN KEY (barcode_id) REFERENCES barcodes(id) ON DELETE SET NULL,
    CONSTRAINT fk_items_unit FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE RESTRICT,
    CONSTRAINT fk_items_currency FOREIGN KEY (currency_id) REFERENCES currencies(id) ON DELETE RESTRICT,
    CONSTRAINT fk_items_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    CHECK (quantity >= 0),
    INDEX (shelf_id),
    INDEX (barcode_id),
    INDEX (unit_id),
    INDEX (currency_id),
    INDEX (category_id)
) ENGINE=InnoDB;

-- =============================================================
-- 16) Create the Recipes Table with a rating (1-5), soft delete, dynamic attributes, and full-text index on instructions
-- =============================================================
CREATE TABLE recipes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    instructions TEXT,
    extra_attributes JSON DEFAULT NULL,
    rating INT DEFAULT NULL,
    deleted_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (rating IS NULL OR (rating BETWEEN 1 AND 5)),
    FULLTEXT INDEX idx_instructions (instructions)
) ENGINE=InnoDB;

-- =============================================================
-- 17) Create the Recipe_Ingredients Table with a free-form 'notes' field and full-text index on notes
-- =============================================================
CREATE TABLE recipe_ingredients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    recipe_id INT NOT NULL,
    barcode_id INT DEFAULT NULL,
    item_name VARCHAR(150) NOT NULL,
    quantity_needed DECIMAL(10,2) DEFAULT 1.0,
    unit_id INT DEFAULT NULL,
    package_description VARCHAR(150),
    notes TEXT,
    CONSTRAINT fk_recipe_ingredients_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
    CONSTRAINT fk_recipe_ingredients_barcode FOREIGN KEY (barcode_id) REFERENCES barcodes(id) ON DELETE SET NULL,
    CONSTRAINT fk_recipe_ingredients_unit FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE SET NULL,
    INDEX (recipe_id),
    INDEX (barcode_id),
    INDEX (unit_id),
    FULLTEXT INDEX idx_notes (notes)
) ENGINE=InnoDB;

-- =============================================================
-- 18) Create the Tags Table
-- =============================================================
CREATE TABLE tags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- =============================================================
-- 19) Create the Item_Tags Mapping Table
-- =============================================================
CREATE TABLE item_tags (
    item_id INT NOT NULL,
    tag_id INT NOT NULL,
    PRIMARY KEY (item_id, tag_id),
    CONSTRAINT fk_item_tags_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    CONSTRAINT fk_item_tags_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================
-- 20) Create the Recipe_Tags Mapping Table
-- =============================================================
CREATE TABLE recipe_tags (
    recipe_id INT NOT NULL,
    tag_id INT NOT NULL,
    PRIMARY KEY (recipe_id, tag_id),
    CONSTRAINT fk_recipe_tags_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
    CONSTRAINT fk_recipe_tags_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================================
-- 21) Create the Settings Table for global configuration
-- =============================================================
CREATE TABLE settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    value VARCHAR(255) NOT NULL,
    description TEXT,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- =============================================================
-- 22) Create the Inventory Table
-- =============================================================
CREATE TABLE inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    barcode_id INT NOT NULL,
    shelf_id INT NOT NULL,
    quantity DECIMAL(10,2) DEFAULT 0.00,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_inventory_barcode FOREIGN KEY (barcode_id) REFERENCES barcodes(id) ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_shelf FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE,
    UNIQUE KEY (barcode_id, shelf_id),
    CHECK (quantity >= 0),
    INDEX (barcode_id),
    INDEX (shelf_id)
) ENGINE=InnoDB;

-- =============================================================
-- 23) Create the Consumption_Actions Table (lookup for actions: USED, WASTED, DONATED, etc.)
-- =============================================================
CREATE TABLE consumption_actions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    action_name VARCHAR(100) NOT NULL,
    description TEXT,
    UNIQUE KEY (action_name)
) ENGINE=InnoDB;

-- =============================================================
-- 24) Create the Consumption_Logs Table
-- =============================================================
CREATE TABLE consumption_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    quantity_used DECIMAL(10,2) NOT NULL,
    used_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action_id INT NOT NULL,
    CONSTRAINT fk_consumption_logs_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    CONSTRAINT fk_consumption_logs_action FOREIGN KEY (action_id) REFERENCES consumption_actions(id) ON DELETE RESTRICT,
    CHECK (quantity_used >= 0),
    INDEX (item_id),
    INDEX (action_id)
) ENGINE=InnoDB;

-- =============================================================
-- 25) Create the Items_Audit Table for historical logging of changes to items
-- =============================================================
CREATE TABLE items_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT,
    operation ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    old_quantity DECIMAL(10,2),
    new_quantity DECIMAL(10,2),
    changed_by INT,
    notes TEXT,
    INDEX (item_id)
) ENGINE=InnoDB;

-- =============================================================
-- 26) Create the Users_Audit Table for historical logging of changes to users
-- =============================================================
CREATE TABLE users_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    operation ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    old_data JSON,
    new_data JSON,
    changed_by INT,
    notes TEXT,
    INDEX (user_id)
) ENGINE=InnoDB;

-- =============================================================
-- 27) Create the Recipes_Audit Table for historical logging of changes to recipes
-- =============================================================
CREATE TABLE recipes_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    recipe_id INT,
    operation ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    old_data JSON,
    new_data JSON,
    changed_by INT,
    notes TEXT,
    INDEX (recipe_id)
) ENGINE=InnoDB;

-- =============================================================
-- 28) Create Triggers for Inventory Updates
-- =============================================================
DELIMITER $$
CREATE TRIGGER trg_items_after_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    IF NEW.barcode_id IS NOT NULL THEN
       INSERT INTO inventory (barcode_id, shelf_id, quantity)
       VALUES (NEW.barcode_id, NEW.shelf_id, NEW.quantity)
       ON DUPLICATE KEY UPDATE quantity = quantity + NEW.quantity;
    END IF;
END$$

CREATE TRIGGER trg_items_after_update
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
    IF OLD.barcode_id IS NOT NULL THEN
         IF OLD.barcode_id = NEW.barcode_id AND OLD.shelf_id = NEW.shelf_id THEN
             SET @diff = NEW.quantity - OLD.quantity;
             UPDATE inventory SET quantity = quantity + @diff
             WHERE barcode_id = NEW.barcode_id AND shelf_id = NEW.shelf_id;
         ELSE
             UPDATE inventory SET quantity = quantity - OLD.quantity
             WHERE barcode_id = OLD.barcode_id AND shelf_id = OLD.shelf_id;
             IF NEW.barcode_id IS NOT NULL THEN
                INSERT INTO inventory (barcode_id, shelf_id, quantity)
                VALUES (NEW.barcode_id, NEW.shelf_id, NEW.quantity)
                ON DUPLICATE KEY UPDATE quantity = quantity + NEW.quantity;
             END IF;
         END IF;
    ELSE
         IF NEW.barcode_id IS NOT NULL THEN
           INSERT INTO inventory (barcode_id, shelf_id, quantity)
           VALUES (NEW.barcode_id, NEW.shelf_id, NEW.quantity)
           ON DUPLICATE KEY UPDATE quantity = quantity + NEW.quantity;
         END IF;
    END IF;
END$$

CREATE TRIGGER trg_items_after_delete
AFTER DELETE ON items
FOR EACH ROW
BEGIN
    IF OLD.barcode_id IS NOT NULL THEN
         UPDATE inventory SET quantity = quantity - OLD.quantity
         WHERE barcode_id = OLD.barcode_id AND shelf_id = OLD.shelf_id;
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- 29) Create Triggers for Items Audit
-- =============================================================
DELIMITER $$
CREATE TRIGGER trg_items_audit_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    INSERT INTO items_audit (item_id, operation, new_quantity, changed_by)
    VALUES (NEW.id, 'INSERT', NEW.quantity, NULL);
END$$

CREATE TRIGGER trg_items_audit_update
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
    INSERT INTO items_audit (item_id, operation, old_quantity, new_quantity, changed_by)
    VALUES (NEW.id, 'UPDATE', OLD.quantity, NEW.quantity, NULL);
END$$

CREATE TRIGGER trg_items_audit_delete
AFTER DELETE ON items
FOR EACH ROW
BEGIN
    INSERT INTO items_audit (item_id, operation, old_quantity, changed_by)
    VALUES (OLD.id, 'DELETE', OLD.quantity, NULL);
END$$
DELIMITER ;

-- =============================================================
-- 30) Create Triggers for Users Audit
-- =============================================================
DELIMITER $$
CREATE TRIGGER trg_users_audit_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (user_id, operation, new_data, changed_by)
    VALUES (NEW.id, 'INSERT', JSON_OBJECT('username', NEW.username, 'email', NEW.email, 'role_id', NEW.role_id), NULL);
END$$

CREATE TRIGGER trg_users_audit_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (user_id, operation, old_data, new_data, changed_by)
    VALUES (NEW.id, 'UPDATE',
            JSON_OBJECT('username', OLD.username, 'email', OLD.email, 'role_id', OLD.role_id),
            JSON_OBJECT('username', NEW.username, 'email', NEW.email, 'role_id', NEW.role_id),
            NULL);
END$$

CREATE TRIGGER trg_users_audit_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (user_id, operation, old_data, changed_by)
    VALUES (OLD.id, 'DELETE', JSON_OBJECT('username', OLD.username, 'email', OLD.email, 'role_id', OLD.role_id), NULL);
END$$
DELIMITER ;

-- =============================================================
-- 31) Create Triggers for Recipes Audit
-- =============================================================
DELIMITER $$
CREATE TRIGGER trg_recipes_audit_insert
AFTER INSERT ON recipes
FOR EACH ROW
BEGIN
    INSERT INTO recipes_audit (recipe_id, operation, new_data, changed_by)
    VALUES (NEW.id, 'INSERT', JSON_OBJECT('name', NEW.name, 'rating', NEW.rating), NULL);
END$$

CREATE TRIGGER trg_recipes_audit_update
AFTER UPDATE ON recipes
FOR EACH ROW
BEGIN
    INSERT INTO recipes_audit (recipe_id, operation, old_data, new_data, changed_by)
    VALUES (NEW.id, 'UPDATE',
            JSON_OBJECT('name', OLD.name, 'rating', OLD.rating),
            JSON_OBJECT('name', NEW.name, 'rating', NEW.rating),
            NULL);
END$$

CREATE TRIGGER trg_recipes_audit_delete
AFTER DELETE ON recipes
FOR EACH ROW
BEGIN
    INSERT INTO recipes_audit (recipe_id, operation, old_data, changed_by)
    VALUES (OLD.id, 'DELETE', JSON_OBJECT('name', OLD.name, 'rating', OLD.rating), NULL);
END$$
DELIMITER ;

-- =============================================================
-- Confirmation Message
-- =============================================================
SELECT 'StashIQ DB with all enhancements created successfully!' AS Status;
