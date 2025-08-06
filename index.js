const express = require('express');
const { Pool } = require('pg');
const app = express();
const port = process.env.PORT || 3000;

// Database connection configuration using environment variables
const dbConfig = {
  host: process.env.DBHOST,       // e.g., "mypgserver.postgres.database.azure.com"
  database: process.env.DBNAME,   // e.g., "postgres" (default database)
  user: process.env.DBUSER,       // e.g., "pgadmin" (admin username)
  password: process.env.DBPASS,   // the admin password
  port: 5432,
  ssl: { rejectUnauthorized: false }  // Require SSL (Azure Postgres requires SSL by default)
};
const pool = new Pool(dbConfig);

// Define a basic route
app.get('/', async (req, res) => {
  try {
    // Query the current time from PostgreSQL (as a simple test)
    const result = await pool.query('SELECT NOW()');
    const currentTime = result.rows[0].now;
    res.send(`Hello! Node.js app is running. Current time from DB is: ${currentTime}`);
  } catch (err) {
    console.error('Database query failed', err);
    res.status(500).send('Error connecting to the database.');
  }
});

// Start the Express server
app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});