const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const port = 3000;

// Middleware
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));
app.set('view engine', 'ejs');

// Database connection
const db = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'employee_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Test database connection
db.getConnection((err, connection) => {
  if (err) {
    console.error('Database connection failed:', err);
  } else {
    console.log('Database connected successfully');
    connection.release();
    
    // Create table if not exists
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS employees (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        department VARCHAR(50),
        role VARCHAR(50),
        status ENUM('pending', 'active', 'inactive') DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `;
    
    db.query(createTableQuery, (err) => {
      if (err) {
        console.error('Error creating table:', err);
      } else {
        console.log('Employees table ready');
      }
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Home page - list all employees
app.get('/', (req, res) => {
  const query = 'SELECT * FROM employees ORDER BY created_at DESC';
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error fetching employees:', err);
      return res.status(500).send('Database error');
    }
    res.render('index', { employees: results });
  });
});

// Add employee form
app.get('/add', (req, res) => {
  res.render('add');
});

// Add employee POST
app.post('/add', (req, res) => {
  const { name, email, department, role } = req.body;
  
  const query = 'INSERT INTO employees (name, email, department, role, status) VALUES (?, ?, ?, ?, ?)';
  
  db.query(query, [name, email, department, role, 'pending'], (err, result) => {
    if (err) {
      console.error('Error adding employee:', err);
      return res.status(500).send('Error adding employee');
    }
    console.log(`New employee added: ${name} (${email})`);
    res.redirect('/');
  });
});

// View employee details
app.get('/employee/:id', (req, res) => {
  const query = 'SELECT * FROM employees WHERE id = ?';
  
  db.query(query, [req.params.id], (err, results) => {
    if (err || results.length === 0) {
      return res.status(404).send('Employee not found');
    }
    res.render('details', { employee: results[0] });
  });
});

// Update employee status
app.post('/employee/:id/status', (req, res) => {
  const { status } = req.body;
  const query = 'UPDATE employees SET status = ? WHERE id = ?';
  
  db.query(query, [status, req.params.id], (err) => {
    if (err) {
      return res.status(500).send('Error updating status');
    }
    res.redirect('/');
  });
});

// Delete employee
app.post('/employee/:id/delete', (req, res) => {
  const query = 'DELETE FROM employees WHERE id = ?';
  
  db.query(query, [req.params.id], (err) => {
    if (err) {
      return res.status(500).send('Error deleting employee');
    }
    res.redirect('/');
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`HR Portal running on port ${port}`);
  console.log(`Database: ${process.env.DB_HOST}`);
});