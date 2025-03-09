# Import necessary modules from Flask
from flask import Flask, request, jsonify, session
# SQLAlchemy is used to interact with our MySQL database
from flask_sqlalchemy import SQLAlchemy
# Flask-CORS to allow cross-origin requests from our React frontend
from flask_cors import CORS
# bcrypt is used to securely compare passwords (you must install it with pip install bcrypt)
import bcrypt

# Initialize our Flask application
app = Flask(__name__)

# Enable CORS to allow our React app to call this API
CORS(app)

# Set a secret key for sessions (change this to a secure random value in production)
app.config['SECRET_KEY'] = 'your-very-secret-key'

# Configure SQLAlchemy to connect to the MySQL database.
# Make sure to replace 'your_username' and 'your_password' with your actual database credentials.
# The database is hosted on {IP Address} and the database name is 'stashiq_db'
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://your_username:your_password@IPAddress/stashiq_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize SQLAlchemy with our Flask app
db = SQLAlchemy(app)

# ------------------------------------------------------------------
# Define a User model to interact with the 'users' table in our database.
# This model should match the schema we defined earlier.
# ------------------------------------------------------------------
class User(db.Model):
    __tablename__ = 'users'  # Name of the table in the database
    id = db.Column(db.Integer, primary_key=True)  # Unique user ID
    username = db.Column(db.String(50), unique=True, nullable=False)  # Username must be unique
    password_hash = db.Column(db.String(255), nullable=False)  # Stored password hash (bcrypt hash)
    email = db.Column(db.String(100))  # User email
    role_id = db.Column(db.Integer, nullable=False)  # User role reference

# ------------------------------------------------------------------
# Create an API endpoint for user login.
# This endpoint accepts a JSON POST request with a username and password.
# If authentication is successful, it stores the user's ID in the session and returns a success message.
# ------------------------------------------------------------------
@app.route('/api/login', methods=['POST'])
def api_login():
    # Get the JSON data from the request
    data = request.get_json()
    # If no JSON data was sent, return an error message
    if not data:
        return jsonify({'error': 'Missing JSON body'}), 400

    # Retrieve the username and password from the JSON data
    username = data.get('username')
    password = data.get('password')

    # Check if both username and password were provided
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400

    # Query the database for a user with the provided username
    user = User.query.filter_by(username=username).first()

    # If the user exists, check if the password is correct using bcrypt
    if user and bcrypt.checkpw(password.encode('utf-8'), user.password_hash.encode('utf-8')):
        # Store the user's id in the session so that the user is "logged in"
        session['user_id'] = user.id
        # Return a success JSON response
        return jsonify({'message': 'Login successful', 'user_id': user.id}), 200
    else:
        # If authentication fails, return an error message
        return jsonify({'error': 'Invalid username or password'}), 401

# ------------------------------------------------------------------
# A simple dashboard route to test login functionality.
# In a real application, this would be replaced with more complex logic.
# ------------------------------------------------------------------
@app.route('/api/dashboard')
def dashboard():
    # Check if the user is logged in by verifying 'user_id' in the session
    if 'user_id' not in session:
        return jsonify({'error': 'Please log in first.'}), 403
    # If logged in, return a welcome message along with the user ID
    return jsonify({'message': f"Welcome to StashIQ Dashboard, User ID: {session['user_id']}"}), 200

# ------------------------------------------------------------------
# Run the Flask application.
# In production, you would run Gunicorn (or another WSGI server) to serve the app.
# ------------------------------------------------------------------
if __name__ == '__main__':
    app.run(debug=True)
