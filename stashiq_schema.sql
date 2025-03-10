-- =============================================================
-- 1) Create or use the database
-- =============================================================
CREATE DATABASE IF NOT EXISTS stashiq_db;
USE stashiq_db;

-- =============================================================
-- 2) Drop existing tables (optional if re-running)
-- =============================================================
DROP TABLE IF EXISTS api_request_logs;
DROP TABLE IF EXISTS nutrition_data;
DROP TABLE IF EXISTS external_integrations;
DROP TABLE IF EXISTS api_keys;
DROP TABLE IF EXISTS food_recalls;
DROP TABLE IF EXISTS custom_codes;
DROP TABLE IF EXISTS scan_history;
DROP TABLE IF EXISTS recipe_attachments;
DROP TABLE IF EXISTS item_attachments;
DROP TABLE IF EXISTS attachments;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS planned_meals;
DROP TABLE IF EXISTS meal_slots;
DROP TABLE IF EXISTS meal_plans;
DROP TABLE IF EXISTS shopping_list_items;
DROP TABLE IF EXISTS shopping_lists;
DROP TABLE IF EXISTS user_allergens;
DROP TABLE IF EXISTS user_dietary_preferences;
DROP TABLE IF EXISTS recipe_dietary_preferences;
DROP TABLE IF EXISTS item_allergens;
DROP TABLE IF EXISTS item_dietary_preferences;
DROP TABLE IF EXISTS allergens;
DROP TABLE IF EXISTS dietary_preferences;
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
    barcode_type ENUM('UPC', 'EAN', 'QR', 'CODE128', 'OTHER') DEFAULT 'UPC',
    last_scanned DATETIME,
    scan_count INT DEFAULT 0,
    source VARCHAR(100),
    verified BOOLEAN DEFAULT FALSE,
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
    reorder_threshold DECIMAL(10,2) DEFAULT NULL,
    reorder_quantity DECIMAL(10,2) DEFAULT NULL,
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
    CONSTRAINT chk_item_expiry_date CHECK (expiry_date IS NULL OR expiry_date > '2000-01-01'),
    CONSTRAINT chk_item_purchase_date CHECK (purchase_date IS NULL OR purchase_date > '2000-01-01'),
    CONSTRAINT chk_item_cost CHECK (cost IS NULL OR cost >= 0),
    CHECK (quantity >= 0),
    INDEX (shelf_id),
    INDEX (barcode_id),
    INDEX (unit_id),
    INDEX (currency_id),
    INDEX (category_id),
    INDEX idx_items_expiry (expiry_date),
    INDEX idx_items_purchase (purchase_date),
    INDEX idx_items_created (created_at),
    INDEX idx_items_updated (updated_at),
    FULLTEXT INDEX ft_items_name (name)
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
    CONSTRAINT chk_recipe_name_length CHECK (LENGTH(name) >= 3),
    FULLTEXT INDEX idx_instructions (instructions),
    FULLTEXT INDEX ft_recipes_name (name),
    FULLTEXT INDEX ft_recipes_description (description),
    INDEX idx_recipes_created (created_at),
    INDEX idx_recipes_updated (updated_at),
    INDEX idx_recipes_rating (rating)
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
    CONSTRAINT chk_recipe_ingredient_quantity CHECK (quantity_needed > 0),
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
    INDEX (action_id),
    INDEX idx_consumption_logs_date (used_at)
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
-- 28) ENHANCEMENT: Dietary Preferences and Allergens
-- =============================================================

-- Create Dietary Preferences Table
CREATE TABLE dietary_preferences (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- Insert common dietary preferences
INSERT INTO dietary_preferences (name, description, icon) VALUES
  ('Vegan', 'Contains no animal products or byproducts', 'leaf'),
  ('Vegetarian', 'Contains no meat but may include animal byproducts like dairy and eggs', 'carrot'),
  ('Gluten-Free', 'Contains no gluten-containing ingredients', 'wheat-alt'),
  ('Dairy-Free', 'Contains no dairy products', 'glass-milk'),
  ('Keto', 'Low carb, high fat food suitable for ketogenic diets', 'bacon'),
  ('Paleo', 'Contains only ingredients that align with paleolithic diet principles', 'drumstick'),
  ('Low-Carb', 'Contains reduced carbohydrates', 'bread-slice'),
  ('Low-Sodium', 'Contains reduced sodium/salt', 'salt'),
  ('Nut-Free', 'Contains no tree nuts or peanuts', 'nuts'),
  ('Sugar-Free', 'Contains no added sugars', 'candy'),
  ('Low-Fat', 'Contains reduced fat content', 'oil-can'),
  ('High-Protein', 'Contains elevated protein content', 'egg'),
  ('Organic', 'Contains ingredients grown without synthetic pesticides or fertilizers', 'seedling'),
  ('Non-GMO', 'Contains no genetically modified organisms', 'dna'),
  ('Halal', 'Prepared according to Islamic dietary laws', 'moon'),
  ('Kosher', 'Prepared according to Jewish dietary laws', 'star-of-david');

-- Create Allergens Table
CREATE TABLE allergens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    severity ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- Insert common allergens
INSERT INTO allergens (name, description, severity) VALUES
  ('Dairy', 'Milk and dairy products', 'MEDIUM'),
  ('Eggs', 'Chicken eggs and egg products', 'MEDIUM'),
  ('Peanuts', 'Peanuts and peanut derivatives', 'HIGH'),
  ('Tree Nuts', 'Includes almonds, walnuts, cashews, etc.', 'HIGH'),
  ('Fish', 'All types of fish', 'HIGH'),
  ('Shellfish', 'Includes shrimp, crab, lobster, etc.', 'HIGH'),
  ('Wheat', 'Wheat and wheat-containing products', 'MEDIUM'),
  ('Soybeans', 'Soybeans and soy derivatives', 'MEDIUM'),
  ('Sesame', 'Sesame seeds and sesame oil', 'MEDIUM'),
  ('Sulfites', 'Used as preservatives in some foods', 'MEDIUM'),
  ('Gluten', 'Protein found in wheat, barley, and rye', 'MEDIUM'),
  ('Mustard', 'Mustard and mustard seeds', 'MEDIUM'),
  ('Celery', 'Celery and celery seeds', 'LOW'),
  ('Lupin', 'Lupin flour and seeds', 'MEDIUM'),
  ('Molluscs', 'Includes oysters, mussels, scallops, etc.', 'HIGH');

-- Create link table between items and dietary preferences
CREATE TABLE item_dietary_preferences (
    item_id INT NOT NULL,
    dietary_preference_id INT NOT NULL,
    PRIMARY KEY (item_id, dietary_preference_id),
    CONSTRAINT fk_item_dietary_items FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    CONSTRAINT fk_item_dietary_prefs FOREIGN KEY (dietary_preference_id) REFERENCES dietary_preferences(id) ON DELETE CASCADE,
    INDEX (dietary_preference_id)
) ENGINE=InnoDB;

-- Create link table between items and allergens
CREATE TABLE item_allergens (
    item_id INT NOT NULL,
    allergen_id INT NOT NULL,
    contains_traces BOOLEAN DEFAULT FALSE,
    notes TEXT,
    PRIMARY KEY (item_id, allergen_id),
    CONSTRAINT fk_item_allergens_items FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    CONSTRAINT fk_item_allergens_allergens FOREIGN KEY (allergen_id) REFERENCES allergens(id) ON DELETE CASCADE,
    INDEX (allergen_id),
    INDEX (contains_traces)
) ENGINE=InnoDB;

-- Create link table between recipes and dietary preferences
CREATE TABLE recipe_dietary_preferences (
    recipe_id INT NOT NULL,
    dietary_preference_id INT NOT NULL,
    PRIMARY KEY (recipe_id, dietary_preference_id),
    CONSTRAINT fk_recipe_dietary_recipes FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
    CONSTRAINT fk_recipe_dietary_prefs FOREIGN KEY (dietary_preference_id) REFERENCES dietary_preferences(id) ON DELETE CASCADE,
    INDEX (dietary_preference_id)
) ENGINE=InnoDB;

-- Create user dietary preferences table
CREATE TABLE user_dietary_preferences (
    user_id INT NOT NULL,
    dietary_preference_id INT NOT NULL,
    importance ENUM('REQUIRED', 'PREFERRED', 'AVOID') DEFAULT 'REQUIRED',
    PRIMARY KEY (user_id, dietary_preference_id),
    CONSTRAINT fk_user_dietary_users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_dietary_prefs FOREIGN KEY (dietary_preference_id) REFERENCES dietary_preferences(id) ON DELETE CASCADE,
    INDEX (dietary_preference_id),
    INDEX (importance)
) ENGINE=InnoDB;

-- Create user allergens table
CREATE TABLE user_allergens (
    user_id INT NOT NULL,
    allergen_id INT NOT NULL,
    severity ENUM('MILD', 'MODERATE', 'SEVERE', 'LIFE_THREATENING') DEFAULT 'MODERATE',
    notes TEXT,
    PRIMARY KEY (user_id, allergen_id),
    CONSTRAINT fk_user_allergens_users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_allergens_allergens FOREIGN KEY (allergen_id) REFERENCES allergens(id) ON DELETE CASCADE,
    INDEX (allergen_id),
    INDEX (severity)
) ENGINE=InnoDB;

-- =============================================================
-- 29) ENHANCEMENT: Shopping List Feature
-- =============================================================

-- Create Shopping List Table
CREATE TABLE shopping_lists (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    CONSTRAINT fk_shopping_lists_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Create Shopping List Items Table
CREATE TABLE shopping_list_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    shopping_list_id INT NOT NULL,
    barcode_id INT,
    item_name VARCHAR(150) NOT NULL,
    quantity DECIMAL(10,2) DEFAULT 1.0,
    unit_id INT,
    price_estimate DECIMAL(10,2),
    currency_id INT NOT NULL DEFAULT 1,
    priority ENUM('LOW', 'MEDIUM', 'HIGH') DEFAULT 'MEDIUM',
    store_preference VARCHAR(100),
    status ENUM('PENDING', 'PURCHASED', 'CANCELLED') DEFAULT 'PENDING',
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_shopping_list_items_list FOREIGN KEY (shopping_list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE,
    CONSTRAINT fk_shopping_list_items_barcode FOREIGN KEY (barcode_id) REFERENCES barcodes(id) ON DELETE SET NULL,
    CONSTRAINT fk_shopping_list_items_unit FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE SET NULL,
    CONSTRAINT fk_shopping_list_items_currency FOREIGN KEY (currency_id) REFERENCES currencies(id) ON DELETE RESTRICT,
    INDEX (shopping_list_id),
    INDEX (barcode_id),
    INDEX (unit_id),
    INDEX (currency_id),
    INDEX (status)
) ENGINE=InnoDB;

-- =============================================================
-- 30) ENHANCEMENT: Meal Planning System
-- =============================================================

-- Create Meal Plans Table
CREATE TABLE meal_plans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    CONSTRAINT fk_meal_plans_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX (start_date),
    INDEX (end_date)
) ENGINE=InnoDB;

-- Create Meal Slots Table
CREATE TABLE meal_slots (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- Insert common meal slots
INSERT INTO meal_slots (name, display_order) VALUES
  ('Breakfast', 1),
  ('Lunch', 2),
  ('Dinner', 3),
  ('Snack', 4);

-- Create Planned Meals Table
CREATE TABLE planned_meals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    meal_plan_id INT NOT NULL,
    recipe_id INT,
    meal_date DATE NOT NULL,
    meal_slot_id INT NOT NULL,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_planned_meals_plan FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
    CONSTRAINT fk_planned_meals_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL,
    CONSTRAINT fk_planned_meals_slot FOREIGN KEY (meal_slot_id) REFERENCES meal_slots(id) ON DELETE RESTRICT,
    INDEX (meal_plan_id),
    INDEX (recipe_id),
    INDEX (meal_date),
    INDEX (meal_slot_id)
) ENGINE=InnoDB;

-- =============================================================
-- 31) ENHANCEMENT: Notifications
-- =============================================================

-- Create Notifications Table
CREATE TABLE notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    type ENUM('EXPIRY', 'LOW_STOCK', 'REORDER', 'SYSTEM') NOT NULL,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    link VARCHAR(255),
    is_read BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX (user_id),
    INDEX (type),
    INDEX (is_read),
    INDEX (created_at)
) ENGINE=InnoDB;

-- =============================================================
-- ENHANCEMENT: Item Attachments
-- =============================================================

-- Create Attachments Table
CREATE TABLE attachments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(100) NOT NULL,
    file_size INT NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    upload_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    uploaded_by INT,
    CONSTRAINT fk_attachments_user FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX (upload_date),
    INDEX (uploaded_by)
) ENGINE=InnoDB;

-- Create Item Attachments Table (for many-to-many relationship)
CREATE TABLE item_attachments (
    item_id INT NOT NULL,
    attachment_id INT NOT NULL,
    attachment_type ENUM('IMAGE', 'RECEIPT', 'DOCUMENT', 'OTHER') NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    description TEXT,
    PRIMARY KEY (item_id, attachment_id),
    CONSTRAINT fk_item_attachments_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    CONSTRAINT fk_item_attachments_attachment FOREIGN KEY (attachment_id) REFERENCES attachments(id) ON DELETE CASCADE,
    INDEX (attachment_type),
    INDEX (is_primary)
) ENGINE=InnoDB;

-- Create Recipe Attachments Table
CREATE TABLE recipe_attachments (
    recipe_id INT NOT NULL,
    attachment_id INT NOT NULL,
    attachment_type ENUM('IMAGE', 'DOCUMENT', 'OTHER') NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    description TEXT,
    PRIMARY KEY (recipe_id, attachment_id),
    CONSTRAINT fk_recipe_attachments_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
    CONSTRAINT fk_recipe_attachments_attachment FOREIGN KEY (attachment_id) REFERENCES attachments(id) ON DELETE CASCADE,
    INDEX (attachment_type),
    INDEX (is_primary)
) ENGINE=InnoDB;

-- =============================================================
-- ENHANCEMENT: Mobile Scan Support
-- =============================================================

-- Create scan history table
CREATE TABLE scan_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    barcode_value VARCHAR(50) NOT NULL,
    scanned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    scanned_by INT,
    device_info VARCHAR(255),
    location_id INT,
    result_status ENUM('FOUND', 'NOT_FOUND', 'AMBIGUOUS', 'ERROR') NOT NULL,
    notes TEXT,
    CONSTRAINT fk_scan_history_user FOREIGN KEY (scanned_by) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_scan_history_location FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE SET NULL,
    INDEX (barcode_value),
    INDEX (scanned_at),
    INDEX (scanned_by),
    INDEX (location_id),
    INDEX (result_status)
) ENGINE=InnoDB;

-- Create custom QR code table for user-generated codes
CREATE TABLE custom_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code_value VARCHAR(50) NOT NULL,
    code_type ENUM('QR', 'BARCODE') DEFAULT 'QR',
    linked_item_id INT,
    linked_recipe_id INT,
    generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    generated_by INT,
    UNIQUE KEY (code_value),
    CONSTRAINT fk_custom_codes_item FOREIGN KEY (linked_item_id) REFERENCES items(id) ON DELETE SET NULL,
    CONSTRAINT fk_custom_codes_recipe FOREIGN KEY (linked_recipe_id) REFERENCES recipes(id) ON DELETE SET NULL,
    CONSTRAINT fk_custom_codes_user FOREIGN KEY (generated_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX (linked_item_id),
    INDEX (linked_recipe_id),
    INDEX (generated_by)
) ENGINE=InnoDB;

-- =============================================================
-- ENHANCEMENT: Food Safety Features
-- =============================================================

-- Create food recall table
CREATE TABLE food_recalls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    manufacturer VARCHAR(100),
    affected_products TEXT NOT NULL,
    recall_date DATE NOT NULL,
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    source_url VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT,
    CONSTRAINT fk_food_recalls_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX (recall_date),
    INDEX (severity),
    INDEX (manufacturer),
    FULLTEXT INDEX ft_food_recalls (title, description, affected_products)
) ENGINE=InnoDB;

-- =============================================================
-- ENHANCEMENT: API Integration Support
-- =============================================================

-- Create API keys table
CREATE TABLE api_keys (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    key_value VARCHAR(255) NOT NULL,
    service_type ENUM('GROCERY', 'RECIPE', 'BARCODE', 'OTHER') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME,
    created_by INT,
    CONSTRAINT fk_api_keys_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY (key_value),
    INDEX (service_type),
    INDEX (is_active)
) ENGINE=InnoDB;

-- Create external service integrations table
CREATE TABLE external_integrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    service_type ENUM('GROCERY', 'RECIPE', 'BARCODE', 'NUTRITION', 'OTHER') NOT NULL,
    base_url VARCHAR(255),
    auth_type ENUM('API_KEY', 'OAUTH', 'BASIC', 'NONE') DEFAULT 'API_KEY',
    auth_details JSON,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    CONSTRAINT fk_external_integrations_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX (service_type),
    INDEX (is_active)
) ENGINE=InnoDB;

-- Create API request logs table
CREATE TABLE api_request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    api_key_id INT,
    endpoint VARCHAR(255) NOT NULL,
    request_method ENUM('GET', 'POST', 'PUT', 'DELETE', 'PATCH') NOT NULL,
    request_headers TEXT,
    request_body TEXT,
    response_code INT,
    response_body TEXT,
    requested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processing_time INT,  -- in milliseconds
    CONSTRAINT fk_api_request_logs_key FOREIGN KEY (api_key_id) REFERENCES api_keys(id) ON DELETE SET NULL,
    INDEX (api_key_id),
    INDEX (endpoint),
    INDEX (requested_at),
    INDEX (response_code)
) ENGINE=InnoDB;

-- Create table for storing nutrition data from external APIs
CREATE TABLE nutrition_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    barcode_id INT NOT NULL,
    calories_per_100g DECIMAL(10,2),
    protein_per_100g DECIMAL(10,2),
    fat_per_100g DECIMAL(10,2),
    carbs_per_100g DECIMAL(10,2),
    fiber_per_100g DECIMAL(10,2),
    sugar_per_100g DECIMAL(10,2),
    sodium_per_100g DECIMAL(10,2),
    data_source VARCHAR(100),
    retrieved_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    raw_data JSON,
    CONSTRAINT fk_nutrition_data_barcode FOREIGN KEY (barcode_id) REFERENCES barcodes(id) ON DELETE CASCADE,
    INDEX (barcode_id),
    INDEX (retrieved_at)
) ENGINE=InnoDB;

-- =============================================================
-- 28) Create Triggers for Inventory Updates
-- =============================================================
DELIMITER $
CREATE TRIGGER trg_items_after_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    IF NEW.barcode_id IS NOT NULL THEN
       INSERT INTO inventory (barcode_id, shelf_id, quantity)
       VALUES (NEW.barcode_id, NEW.shelf_id, NEW.quantity)
       ON DUPLICATE KEY UPDATE quantity = quantity + NEW.quantity;
    END IF;
END$

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
END$

CREATE TRIGGER trg_items_after_delete
AFTER DELETE ON items
FOR EACH ROW
BEGIN
    IF OLD.barcode_id IS NOT NULL THEN
         UPDATE inventory SET quantity = quantity - OLD.quantity
         WHERE barcode_id = OLD.barcode_id AND shelf_id = OLD.shelf_id;
    END IF;
END$
DELIMITER ;

-- =============================================================
-- 29) Create Triggers for Items Audit
-- =============================================================
DELIMITER $
CREATE TRIGGER trg_items_audit_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    INSERT INTO items_audit (item_id, operation, new_quantity, changed_by)
    VALUES (NEW.id, 'INSERT', NEW.quantity, NULL);
END$

CREATE TRIGGER trg_items_audit_update
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
    INSERT INTO items_audit (item_id, operation, old_quantity, new_quantity, changed_by)
    VALUES (NEW.id, 'UPDATE', OLD.quantity, NEW.quantity, NULL);
END$

CREATE TRIGGER trg_items_audit_delete
AFTER DELETE ON items
FOR EACH ROW
BEGIN
    INSERT INTO items_audit (item_id, operation, old_quantity, changed_by)
    VALUES (OLD.id, 'DELETE', OLD.quantity, NULL);
END$
DELIMITER ;

-- =============================================================
-- 30) Create Triggers for Users Audit
-- =============================================================
DELIMITER $
CREATE TRIGGER trg_users_audit_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (user_id, operation, new_data, changed_by)
    VALUES (NEW.id, 'INSERT', JSON_OBJECT('username', NEW.username, 'email', NEW.email, 'role_id', NEW.role_id), NULL);
END$

CREATE TRIGGER trg_users_audit_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (user_id, operation, old_data, new_data, changed_by)
    VALUES (NEW.id, 'UPDATE',
            JSON_OBJECT('username', OLD.username, 'email', OLD.email, 'role_id', OLD.role_id),
            JSON_OBJECT('username', NEW.username, 'email', NEW.email, 'role_id', NEW.role_id),
            NULL);
END$

CREATE TRIGGER trg_users_audit_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (user_id, operation, old_data, changed_by)
    VALUES (OLD.id, 'DELETE', JSON_OBJECT('username', OLD.username, 'email', OLD.email, 'role_id', OLD.role_id), NULL);
END$
DELIMITER ;

-- =============================================================
-- 31) Create Triggers for Recipes Audit
-- =============================================================
DELIMITER $
CREATE TRIGGER trg_recipes_audit_insert
AFTER INSERT ON recipes
FOR EACH ROW
BEGIN
    INSERT INTO recipes_audit (recipe_id, operation, new_data, changed_by)
    VALUES (NEW.id, 'INSERT', JSON_OBJECT('name', NEW.name, 'rating', NEW.rating), NULL);
END$

CREATE TRIGGER trg_recipes_audit_update
AFTER UPDATE ON recipes
FOR EACH ROW
BEGIN
    INSERT INTO recipes_audit (recipe_id, operation, old_data, new_data, changed_by)
    VALUES (NEW.id, 'UPDATE',
            JSON_OBJECT('name', OLD.name, 'rating', OLD.rating),
            JSON_OBJECT('name', NEW.name, 'rating', NEW.rating),
            NULL);
END$

CREATE TRIGGER trg_recipes_audit_delete
AFTER DELETE ON recipes
FOR EACH ROW
BEGIN
    INSERT INTO recipes_audit (recipe_id, operation, old_data, changed_by)
    VALUES (OLD.id, 'DELETE', JSON_OBJECT('name', OLD.name, 'rating', OLD.rating), NULL);
END$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Item Reorder Points - Low Stock Trigger
-- =============================================================
DELIMITER $$
CREATE TRIGGER trg_items_check_stock
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
    -- Check if quantity falls below threshold and a threshold is set
    IF NEW.reorder_threshold IS NOT NULL AND NEW.quantity < NEW.reorder_threshold AND OLD.quantity >= NEW.reorder_threshold THEN
        -- Insert notification for all users (assuming admin users should be notified)
        INSERT INTO notifications (user_id, type, title, message)
        SELECT id, 'LOW_STOCK', CONCAT('Low stock: ', NEW.name), 
               CONCAT('The current stock of ', NEW.name, ' (', NEW.quantity, ' ', 
                     (SELECT name FROM units WHERE id = NEW.unit_id), 
                     ') is below the reorder threshold of ', NEW.reorder_threshold)
        FROM users 
        WHERE role_id = 1; -- Assuming role_id 1 is for admins
    END IF;
END$$

-- =============================================================
-- ENHANCEMENT: Allergen Warning Trigger
-- =============================================================
CREATE TRIGGER trg_allergen_warning
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    -- If the new item has allergens
    IF EXISTS (
        SELECT 1 FROM item_allergens WHERE item_id = NEW.id
    ) THEN
        -- Find users with matching allergens and notify them
        INSERT INTO notifications (user_id, type, title, message)
        SELECT 
            ua.user_id,
            'SYSTEM',
            CONCAT('Allergen Alert: New item contains ', a.name),
            CONCAT('A new item "', NEW.name, '" contains allergens you\'ve flagged: ', a.name, '. It was added to ', 
                  (SELECT name FROM shelves WHERE id = NEW.shelf_id), ' in ',
                  (SELECT l.name FROM shelves s JOIN locations l ON s.location_id = l.id WHERE s.id = NEW.shelf_id))
        FROM 
            item_allergens ia
        JOIN 
            allergens a ON ia.allergen_id = a.id
        JOIN 
            user_allergens ua ON ia.allergen_id = ua.allergen_id
        WHERE 
            ia.item_id = NEW.id;
    END IF;
END$$

-- =============================================================
-- ENHANCEMENT: Auto-update Recipe Dietary Preferences
-- =============================================================
CREATE TRIGGER trg_update_recipe_dietary_prefs
AFTER INSERT ON recipe_ingredients
FOR EACH ROW
BEGIN
    -- Find items with the barcode
    IF NEW.barcode_id IS NOT NULL THEN
        -- Get all dietary preferences from the items with this barcode
        INSERT IGNORE INTO recipe_dietary_preferences (recipe_id, dietary_preference_id)
        SELECT 
            NEW.recipe_id,
            idp.dietary_preference_id
        FROM 
            items i
        JOIN 
            item_dietary_preferences idp ON i.id = idp.item_id
        WHERE 
            i.barcode_id = NEW.barcode_id
            AND i.deleted_at IS NULL;
    END IF;
END$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Dietary Compatibility Function
-- =============================================================
DELIMITER $$
CREATE FUNCTION is_item_dietary_compatible(
    p_item_id INT,
    p_dietary_preference_id INT
) RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE is_compatible BOOLEAN;
    
    SELECT EXISTS (
        SELECT 1 
        FROM item_dietary_preferences 
        WHERE item_id = p_item_id 
        AND dietary_preference_id = p_dietary_preference_id
    ) INTO is_compatible;
    
    RETURN is_compatible;
END$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Meal Plan to Shopping List Procedure
-- =============================================================
DELIMITER $$
CREATE PROCEDURE generate_shopping_list_from_meal_plan(
    IN p_meal_plan_id INT,
    IN p_shopping_list_name VARCHAR(100),
    OUT p_shopping_list_id INT
)
BEGIN
    -- Create a new shopping list
    INSERT INTO shopping_lists (name, description, created_by)
    SELECT CONCAT('Shopping for: ', p_shopping_list_name), 
           CONCAT('Generated from meal plan: ', name),
           created_by
    FROM meal_plans
    WHERE id = p_meal_plan_id;
    
    SET p_shopping_list_id = LAST_INSERT_ID();
    
    -- Add all required ingredients to the shopping list
    INSERT INTO shopping_list_items (
        shopping_list_id, 
        barcode_id, 
        item_name, 
        quantity,
        unit_id,
        notes
    )
    SELECT 
        p_shopping_list_id,
        ri.barcode_id,
        ri.item_name,
        SUM(ri.quantity_needed),
        ri.unit_id,
        CONCAT('For recipes: ', GROUP_CONCAT(r.name SEPARATOR ', '))
    FROM planned_meals pm
    JOIN recipes r ON pm.recipe_id = r.id
    JOIN recipe_ingredients ri ON r.id = ri.recipe_id
    WHERE pm.meal_plan_id = p_meal_plan_id
    GROUP BY ri.barcode_id, ri.item_name, ri.unit_id;
END$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Check Expiring Items Procedure
-- =============================================================
DELIMITER $$
CREATE PROCEDURE check_expiring_items(IN days_threshold INT)
BEGIN
    -- Get items expiring within the specified days
    INSERT INTO notifications (user_id, type, title, message)
    SELECT 
        u.id, 
        'EXPIRY', 
        CONCAT('Expiring soon: ', COUNT(*), ' items'),
        CONCAT('The following items will expire within ', days_threshold, ' days: ',
               GROUP_CONCAT(i.name SEPARATOR ', '))
    FROM items i
    CROSS JOIN users u
    WHERE i.expiry_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL days_threshold DAY)
    AND u.role_id = 1 -- Assuming role_id 1 is for admins
    AND i.deleted_at IS NULL
    GROUP BY u.id;
END$$
DELIMITER ;

-- Create an event to run the expiry check procedure daily
CREATE EVENT IF NOT EXISTS evt_daily_expiry_check
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
    CALL check_expiring_items(7);

-- =============================================================
-- ENHANCEMENT: Food Safety Check Procedure
-- =============================================================
DELIMITER $$
CREATE PROCEDURE check_food_safety()
BEGIN
    -- Identify items past expiration date
    INSERT INTO notifications (user_id, type, title, message)
    SELECT 
        u.id, 
        'EXPIRY', 
        'Items past expiration date',
        CONCAT('The following items are expired: ',
               GROUP_CONCAT(
                   CONCAT(i.name, ' (expired ', 
                          ABS(DATEDIFF(i.expiry_date, CURDATE())), 
                          ' days ago)')
               SEPARATOR ', '))
    FROM items i
    CROSS JOIN users u
    WHERE i.expiry_date < CURDATE()
    AND i.deleted_at IS NULL
    AND u.role_id = 1  -- Assuming role_id 1 is for admins
    GROUP BY u.id;
    
    -- Check for affected items in recalls
    INSERT INTO notifications (user_id, type, title, message, link)
    SELECT 
        u.id, 
        'SYSTEM', 
        CONCAT('RECALL ALERT: Possible affected items for recall "', fr.title, '"'),
        CONCAT('You may have items affected by a food recall: ', 
               GROUP_CONCAT(i.name SEPARATOR ', '), 
               '. Recall details: ', fr.description),
        fr.source_url
    FROM food_recalls fr
    JOIN items i ON 
        (i.name LIKE CONCAT('%', fr.manufacturer, '%') OR 
         JSON_CONTAINS(i.extra_attributes, CONCAT('"', fr.manufacturer, '"'), '$.manufacturer'))
        AND i.deleted_at IS NULL
    CROSS JOIN users u
    WHERE fr.recall_date > DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    AND u.role_id = 1  -- Assuming role_id 1 is for admins
    GROUP BY fr.id, u.id;
END$$
DELIMITER ;

-- Create an event to run the food safety check procedure daily
CREATE EVENT IF NOT EXISTS evt_daily_food_safety_check
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
    CALL check_food_safety();

-- =============================================================
-- ENHANCEMENT: Recipe Dietary Compatibility Check Procedure
-- =============================================================
DELIMITER $$
CREATE PROCEDURE check_recipe_dietary_compatibility(
    IN p_recipe_id INT,
    IN p_user_id INT
)
BEGIN
    -- Identify user's required dietary preferences
    WITH user_required_prefs AS (
        SELECT 
            dp.id, 
            dp.name
        FROM 
            user_dietary_preferences udp
        JOIN 
            dietary_preferences dp ON udp.dietary_preference_id = dp.id
        WHERE 
            udp.user_id = p_user_id
            AND udp.importance = 'REQUIRED'
    ),
    
    -- Identify user's allergens
    user_allergens AS (
        SELECT 
            a.id, 
            a.name,
            ua.severity
        FROM 
            user_allergens ua
        JOIN 
            allergens a ON ua.allergen_id = a.id
        WHERE 
            ua.user_id = p_user_id
    ),
    
    -- Get recipe dietary preferences
    recipe_prefs AS (
        SELECT 
            dp.id, 
            dp.name
        FROM 
            recipe_dietary_preferences rdp
        JOIN 
            dietary_preferences dp ON rdp.dietary_preference_id = dp.id
        WHERE 
            rdp.recipe_id = p_recipe_id
    ),
    
    -- Get recipe ingredients allergens
    recipe_allergens AS (
        SELECT 
            a.id,
            a.name,
            MAX(CASE WHEN ia.contains_traces = 1 THEN 'TRACES' ELSE 'CONTAINS' END) AS presence_type
        FROM 
            recipe_ingredients ri
        JOIN 
            items i ON ri.barcode_id = i.barcode_id
        JOIN 
            item_allergens ia ON i.id = ia.item_id
        JOIN 
            allergens a ON ia.allergen_id = a.id
        WHERE 
            ri.recipe_id = p_recipe_id
        GROUP BY 
            a.id, a.name
    )
    
    -- Check for compatibility issues
    SELECT 
        r.name AS recipe_name,
        
        -- Missing required dietary preferences
        (SELECT 
            GROUP_CONCAT(urp.name SEPARATOR ', ')
         FROM 
            user_required_prefs urp
         LEFT JOIN 
            recipe_prefs rp ON urp.id = rp.id
         WHERE 
            rp.id IS NULL
        ) AS missing_dietary_preferences,
        
        -- Allergen conflicts
        (SELECT 
            GROUP_CONCAT(
                CONCAT(ra.name, ' (', ra.presence_type, ')')
                SEPARATOR ', '
            )
         FROM 
            recipe_allergens ra
         JOIN 
            user_allergens ua ON ra.id = ua.id
        ) AS allergen_conflicts,
        
        -- Overall compatibility status
        CASE 
            WHEN (SELECT COUNT(*) FROM user_required_prefs urp LEFT JOIN recipe_prefs rp ON urp.id = rp.id WHERE rp.id IS NULL) > 0
                 OR (SELECT COUNT(*) FROM recipe_allergens ra JOIN user_allergens ua ON ra.id = ua.id) > 0
            THEN 'INCOMPATIBLE'
            ELSE 'COMPATIBLE'
        END AS compatibility_status
    FROM 
        recipes r
    WHERE 
        r.id = p_recipe_id;
END$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Data Validation Procedure
-- =============================================================
DELIMITER $$
CREATE PROCEDURE validate_data()
BEGIN
    -- Flag items with inconsistent data
    SELECT 
        id, 
        name, 
        'Expiry date before purchase date' AS issue
    FROM 
        items
    WHERE 
        expiry_date < purchase_date
        AND expiry_date IS NOT NULL
        AND purchase_date IS NOT NULL;
        
    -- Flag items with unreasonable costs
    SELECT 
        id, 
        name,
        cost,
        'Potentially incorrect cost' AS issue
    FROM 
        items
    WHERE 
        (cost > 1000 OR cost < 0.01)
        AND cost IS NOT NULL;
        
    -- Flag recipes with no ingredients
    SELECT 
        r.id,
        r.name,
        'Recipe has no ingredients' AS issue
    FROM 
        recipes r
    LEFT JOIN 
        recipe_ingredients ri ON r.id = ri.recipe_id
    WHERE 
        ri.id IS NULL
        AND r.deleted_at IS NULL;
end$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Advanced Search Procedure
-- =============================================================
DELIMITER $$
CREATE PROCEDURE search_inventory(IN search_term VARCHAR(255))
BEGIN
    -- Search items
    (SELECT 
        'ITEM' AS result_type,
        i.id AS result_id,
        i.name AS result_name,
        i.quantity AS result_quantity,
        u.name AS result_unit,
        CASE 
            WHEN i.expiry_date IS NULL THEN 'n/a'
            ELSE DATE_FORMAT(i.expiry_date, '%Y-%m-%d')
        END AS result_date,
        MATCH(i.name) AGAINST(search_term IN NATURAL LANGUAGE MODE) AS relevance
    FROM 
        items i
    JOIN 
        units u ON i.unit_id = u.id
    WHERE 
        MATCH(i.name) AGAINST(search_term IN NATURAL LANGUAGE MODE)
        AND i.deleted_at IS NULL
    )
    
    UNION
    
    -- Search recipes
    (SELECT 
        'RECIPE' AS result_type,
        r.id AS result_id,
        r.name AS result_name,
        r.rating AS result_quantity,
        'stars' AS result_unit,
        DATE_FORMAT(r.created_at, '%Y-%m-%d') AS result_date,
        MATCH(r.name, r.description, r.instructions) AGAINST(search_term IN NATURAL LANGUAGE MODE) AS relevance
    FROM 
        recipes r
    WHERE 
        MATCH(r.name, r.description, r.instructions) AGAINST(search_term IN NATURAL LANGUAGE MODE)
        AND r.deleted_at IS NULL
    )
    
    ORDER BY relevance DESC
    LIMIT 20;
END$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Create Views for Data Analysis
-- =============================================================

-- Create view for expiring items
CREATE VIEW vw_expiring_items AS
SELECT 
    i.id,
    i.name,
    i.quantity,
    u.name AS unit,
    i.expiry_date,
    DATEDIFF(i.expiry_date, CURDATE()) AS days_until_expiry,
    l.name AS location,
    s.name AS shelf,
    c.name AS category
FROM 
    items i
JOIN 
    units u ON i.unit_id = u.id
JOIN 
    shelves s ON i.shelf_id = s.id
JOIN 
    locations l ON s.location_id = l.id
LEFT JOIN 
    categories c ON i.category_id = c.id
WHERE 
    i.expiry_date IS NOT NULL
    AND i.deleted_at IS NULL
ORDER BY 
    i.expiry_date;

-- Create view for inventory status
CREATE VIEW vw_inventory_status AS
SELECT 
    b.barcode_value,
    b.default_name,
    SUM(i.quantity) AS total_quantity,
    u.name AS unit,
    COUNT(DISTINCT l.id) AS location_count,
    GROUP_CONCAT(DISTINCT l.name SEPARATOR ', ') AS locations
FROM 
    inventory inv
JOIN 
    barcodes b ON inv.barcode_id = b.id
JOIN 
    shelves s ON inv.shelf_id = s.id
JOIN 
    locations l ON s.location_id = l.id
JOIN 
    items i ON i.barcode_id = b.id AND i.deleted_at IS NULL
JOIN 
    units u ON b.default_unit_id = u.id
GROUP BY 
    b.id, u.id;

-- Create view for item dietary information
CREATE VIEW vw_item_dietary_info AS
SELECT 
    i.id AS item_id,
    i.name AS item_name,
    GROUP_CONCAT(DISTINCT dp.name ORDER BY dp.name SEPARATOR ', ') AS dietary_preferences,
    GROUP_CONCAT(DISTINCT 
        CASE 
            WHEN ia.contains_traces = 1 THEN CONCAT(a.name, ' (traces)')
            ELSE a.name
        END 
        ORDER BY a.name SEPARATOR ', '
    ) AS allergens
FROM 
    items i
LEFT JOIN 
    item_dietary_preferences idp ON i.id = idp.item_id
LEFT JOIN 
    dietary_preferences dp ON idp.dietary_preference_id = dp.id
LEFT JOIN 
    item_allergens ia ON i.id = ia.item_id
LEFT JOIN 
    allergens a ON ia.allergen_id = a.id
WHERE 
    i.deleted_at IS NULL
GROUP BY 
    i.id;

-- Create view for recipe dietary information
CREATE VIEW vw_recipe_dietary_info AS
SELECT 
    r.id AS recipe_id,
    r.name AS recipe_name,
    GROUP_CONCAT(DISTINCT dp.name ORDER BY dp.name SEPARATOR ', ') AS dietary_preferences,
    
    -- Find allergens from ingredients
    (SELECT 
        GROUP_CONCAT(DISTINCT a.name ORDER BY a.name SEPARATOR ', ')
     FROM 
        recipe_ingredients ri
     JOIN 
        items i ON ri.barcode_id = i.barcode_id
     JOIN 
        item_allergens ia ON i.id = ia.item_id
     JOIN 
        allergens a ON ia.allergen_id = a.id
     WHERE 
        ri.recipe_id = r.id
     GROUP BY 
        ri.recipe_id) AS potential_allergens
FROM 
    recipes r
LEFT JOIN 
    recipe_dietary_preferences rdp ON r.id = rdp.recipe_id
LEFT JOIN 
    dietary_preferences dp ON rdp.dietary_preference_id = dp.id
WHERE 
    r.deleted_at IS NULL
GROUP BY 
    r.id;

-- Add monthly consumption view
CREATE VIEW vw_monthly_consumption AS
SELECT 
    DATE_FORMAT(cl.used_at, '%Y-%m') AS month,
    ca.action_name,
    SUM(cl.quantity_used) AS total_quantity,
    COUNT(DISTINCT cl.item_id) AS unique_items,
    SUM(i.cost * (cl.quantity_used / i.quantity)) AS estimated_cost
FROM 
    consumption_logs cl
JOIN 
    consumption_actions ca ON cl.action_id = ca.id
JOIN 
    items i ON cl.item_id = i.id
GROUP BY 
    DATE_FORMAT(cl.used_at, '%Y-%m'), ca.action_name
ORDER BY 
    month DESC, ca.action_name;

-- Create category consumption view
CREATE VIEW vw_category_consumption AS
SELECT 
    c.name AS category,
    ca.action_name,
    SUM(cl.quantity_used) AS total_quantity,
    COUNT(DISTINCT cl.item_id) AS unique_items,
    SUM(i.cost * (cl.quantity_used / i.quantity)) AS estimated_cost
FROM 
    consumption_logs cl
JOIN 
    consumption_actions ca ON cl.action_id = ca.id
JOIN 
    items i ON cl.item_id = i.id
LEFT JOIN 
    categories c ON i.category_id = c.id
GROUP BY 
    c.id, ca.action_name
ORDER BY 
    estimated_cost DESC;

-- Create expense tracking view
CREATE VIEW vw_expense_tracking AS
SELECT 
    DATE_FORMAT(i.purchase_date, '%Y-%m') AS month,
    c.name AS category,
    COUNT(i.id) AS item_count,
    SUM(i.cost) AS total_cost,
    cu.code AS currency
FROM 
    items i
LEFT JOIN 
    categories c ON i.category_id = c.id
JOIN 
    currencies cu ON i.currency_id = cu.id
WHERE 
    i.purchase_date IS NOT NULL
    AND i.deleted_at IS NULL
GROUP BY 
    DATE_FORMAT(i.purchase_date, '%Y-%m'), c.id, cu.id
ORDER BY 
    month DESC, total_cost DESC;

-- =============================================================
-- ENHANCEMENT: Analyze Expiration Waste
-- =============================================================
DELIMITER $$
CREATE PROCEDURE analyze_expiration_waste(IN start_date DATE, IN end_date DATE)
BEGIN
    SELECT 
        c.name AS category,
        COUNT(cl.id) AS waste_events,
        SUM(cl.quantity_used) AS wasted_quantity,
        SUM(i.cost * (cl.quantity_used / i.quantity)) AS wasted_value,
        AVG(DATEDIFF(cl.used_at, i.expiry_date)) AS avg_days_past_expiry
    FROM 
        consumption_logs cl
    JOIN 
        consumption_actions ca ON cl.action_id = ca.id
    JOIN 
        items i ON cl.item_id = i.id
    LEFT JOIN 
        categories c ON i.category_id = c.id
    WHERE 
        ca.action_name = 'WASTED'
        AND cl.used_at BETWEEN start_date AND end_date
        AND i.expiry_date IS NOT NULL
    GROUP BY 
        c.id
    ORDER BY 
        wasted_value DESC;
END$$
DELIMITER ;

-- =============================================================
-- ENHANCEMENT: Waste Expense Tracking
-- =============================================================

-- Create view for waste tracking
CREATE VIEW vw_waste_tracking AS
SELECT 
    DATE_FORMAT(cl.used_at, '%Y-%m') AS month,
    c.name AS category,
    COUNT(cl.id) AS waste_events,
    SUM(cl.quantity_used) AS wasted_quantity,
    SUM(i.cost * (cl.quantity_used / i.quantity)) AS wasted_value,
    cu.code AS currency,
    CASE 
        WHEN i.expiry_date IS NOT NULL AND cl.used_at > i.expiry_date 
        THEN 'Expired'
        ELSE 'Other'
    END AS waste_reason
FROM 
    consumption_logs cl
JOIN 
    consumption_actions ca ON cl.action_id = ca.id
JOIN 
    items i ON cl.item_id = i.id
JOIN 
    currencies cu ON i.currency_id = cu.id
LEFT JOIN 
    categories c ON i.category_id = c.id
WHERE 
    ca.action_name = 'WASTED'
GROUP BY 
    DATE_FORMAT(cl.used_at, '%Y-%m'),
    c.id,
    cu.code,
    waste_reason
ORDER BY 
    month DESC, 
    wasted_value DESC;

-- Update existing expense tracking view to include waste information
CREATE OR REPLACE VIEW vw_expense_tracking AS
SELECT 
    month,
    category,
    'Purchase' AS expense_type,
    item_count,
    total_cost,
    currency
FROM (
    SELECT 
        DATE_FORMAT(i.purchase_date, '%Y-%m') AS month,
        c.name AS category,
        COUNT(i.id) AS item_count,
        SUM(i.cost) AS total_cost,
        cu.code AS currency
    FROM 
        items i
    LEFT JOIN 
        categories c ON i.category_id = c.id
    JOIN 
        currencies cu ON i.currency_id = cu.id
    WHERE 
        i.purchase_date IS NOT NULL
        AND i.deleted_at IS NULL
    GROUP BY 
        DATE_FORMAT(i.purchase_date, '%Y-%m'), c.id, cu.id
) AS purchases

UNION ALL

SELECT 
    month,
    category,
    CONCAT('Waste (', waste_reason, ')') AS expense_type,
    waste_events AS item_count,
    wasted_value AS total_cost,
    currency
FROM
    vw_waste_tracking

ORDER BY 
    month DESC, 
    category,
    expense_type;

-- Create a comprehensive reporting procedure
DELIMITER $$
CREATE PROCEDURE generate_expense_waste_report(
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    -- Purchase expenses by category
    SELECT 
        'PURCHASES' AS report_section,
        c.name AS category,
        COUNT(i.id) AS item_count,
        SUM(i.cost) AS total_cost,
        SUM(i.cost) / COUNT(DISTINCT DATE_FORMAT(i.purchase_date, '%Y-%m')) AS monthly_average
    FROM 
        items i
    LEFT JOIN 
        categories c ON i.category_id = c.id
    WHERE 
        i.purchase_date BETWEEN start_date AND end_date
        AND i.deleted_at IS NULL
    GROUP BY 
        c.id
    
    UNION ALL
    
    -- Waste by category
    SELECT 
        'WASTE' AS report_section,
        c.name AS category,
        COUNT(cl.id) AS item_count,
        SUM(i.cost * (cl.quantity_used / i.quantity)) AS total_cost,
        SUM(i.cost * (cl.quantity_used / i.quantity)) / 
            COUNT(DISTINCT DATE_FORMAT(cl.used_at, '%Y-%m')) AS monthly_average
    FROM 
        consumption_logs cl
    JOIN 
        consumption_actions ca ON cl.action_id = ca.id
    JOIN 
        items i ON cl.item_id = i.id
    LEFT JOIN 
        categories c ON i.category_id = c.id
    WHERE 
        ca.action_name = 'WASTED'
        AND cl.used_at BETWEEN start_date AND end_date
    GROUP BY 
        c.id
    
    UNION ALL
    
    -- Waste percentage of purchases
    SELECT 
        'WASTE PERCENTAGE' AS report_section,
        c.name AS category,
        NULL AS item_count,
        (waste_cost / purchase_cost * 100) AS total_cost,
        NULL AS monthly_average
    FROM (
        -- Purchases by category
        SELECT 
            c.id,
            SUM(i.cost) AS purchase_cost
        FROM 
            items i
        LEFT JOIN 
            categories c ON i.category_id = c.id
        WHERE 
            i.purchase_date BETWEEN start_date AND end_date
            AND i.deleted_at IS NULL
        GROUP BY 
            c.id
    ) AS purchases
    JOIN (
        -- Waste by category
        SELECT 
            c.id,
            SUM(i.cost * (cl.quantity_used / i.quantity)) AS waste_cost
        FROM 
            consumption_logs cl
        JOIN 
            consumption_actions ca ON cl.action_id = ca.id
        JOIN 
            items i ON cl.item_id = i.id
        LEFT JOIN 
            categories c ON i.category_id = c.id
        WHERE 
            ca.action_name = 'WASTED'
            AND cl.used_at BETWEEN start_date AND end_date
        GROUP BY 
            c.id
    ) AS waste ON purchases.id = waste.id
    JOIN categories c ON c.id = purchases.id
    
    ORDER BY 
        report_section,
        total_cost DESC;
END$$
DELIMITER ;

-- Create a monthly waste summary view
CREATE VIEW vw_monthly_waste_summary AS
SELECT
    DATE_FORMAT(cl.used_at, '%Y-%m') AS month,
    SUM(i.cost * (cl.quantity_used / i.quantity)) AS waste_value,
    
    -- Add purchase total for the same month for comparison
    (SELECT SUM(i2.cost)
     FROM items i2
     WHERE DATE_FORMAT(i2.purchase_date, '%Y-%m') = DATE_FORMAT(cl.used_at, '%Y-%m')
    ) AS purchase_value,
    
    -- Calculate waste percentage
    (SUM(i.cost * (cl.quantity_used / i.quantity)) / 
     (SELECT SUM(i2.cost)
      FROM items i2
      WHERE DATE_FORMAT(i2.purchase_date, '%Y-%m') = DATE_FORMAT(cl.used_at, '%Y-%m')
     ) * 100
    ) AS waste_percentage,
    
    COUNT(DISTINCT cl.item_id) AS wasted_items,
    SUM(cl.quantity_used) AS wasted_quantity
FROM
    consumption_logs cl
JOIN
    consumption_actions ca ON cl.action_id = ca.id
JOIN
    items i ON cl.item_id = i.id
WHERE
    ca.action_name = 'WASTED'
GROUP BY
    DATE_FORMAT(cl.used_at, '%Y-%m')
ORDER BY
    month DESC;

-- =============================================================
-- Confirmation Message
-- =============================================================
SELECT 'StashIQ DB with all enhancements created successfully!' AS Status;
