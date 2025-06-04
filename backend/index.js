// index.js

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
const port = 8080;

const pool = new Pool({
  host: '192.168.101.5',
	port: 5431,
	database: 'postgres',
	user: 'president',
	password : 'president123',
});

function parseLatLon(rawValue, isLat = true) {
  if (!rawValue || typeof rawValue !== 'string') return null;

  const match = rawValue.match(/([0-9]+\.[0-9]+)/);
  if (!match) return null;

  const num = parseFloat(match[1]);
  const degrees = Math.floor(num / 100);
  const minutes = num - degrees * 100;
  const decimal = degrees + minutes / 60;

  return isLat ? -decimal : decimal;
}

// Existing endpoint - no changes
app.get('/api/gnss5', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT DISTINCT ON (gnss_id, sensor_id) *
      FROM gnss
      WHERE gnss_id IN ('GNSS1', 'GNSS2', 'GNSS3', 'GNSS4', 'GNSS5')
      ORDER BY gnss_id, sensor_id, timestamp DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('Error querying GNSS data:', err);
    res.status(500).send('Error querying GNSS data');
  }
});

// Updated /api/gnss-coords endpoint with combined query
app.get('/api/gnss-coords', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT gnss_id, sensor_id, value
      FROM gnss
      WHERE sensor_id IN ('LAT01', 'LAT02', 'LAT05', 'LON01', 'LON02', 'LON05')
      ORDER BY gnss_id, sensor_id, timestamp DESC
    `);

    const coordsMap = {};

    for (const row of result.rows) {
      if (!coordsMap[row.gnss_id]) coordsMap[row.gnss_id] = {};
      if (row.sensor_id.startsWith('LAT')) {
        const parsedLat = parseLatLon(row.value, true);
        if (parsedLat !== null) coordsMap[row.gnss_id].latitude = parsedLat;
      } else if (row.sensor_id.startsWith('LON')) {
        const parsedLon = parseLatLon(row.value, false);
        if (parsedLon !== null) coordsMap[row.gnss_id].longitude = parsedLon;
      }
    }

    const coords = Object.entries(coordsMap)
      .filter(([_, val]) =>
        typeof val.latitude === 'number' &&
        typeof val.longitude === 'number' &&
        !isNaN(val.latitude) &&
        !isNaN(val.longitude)
      )
      .map(([id, val]) => ({ gnss_id: id, latitude: val.latitude, longitude: val.longitude }));

    res.json(coords);
  } catch (err) {
    console.error('Error fetching coordinates:', err);
    res.status(500).send('Error fetching coordinates');
  }
});

// Existing endpoint - unchanged
app.get('/api/gnss_ids', async (req, res) => {
  try {
    const result = await pool.query(`SELECT DISTINCT gnss_id FROM gnss`);
    res.json(result.rows.map(row => row.gnss_id));
  } catch (err) {
    console.error('Error fetching GNSS IDs:', err);
    res.status(500).send('Error fetching GNSS IDs');
  }
});

// Existing endpoint - unchanged
app.get('/api/sensors/:gnssId', async (req, res) => {
  const { gnssId } = req.params;
  try {
    const result = await pool.query(
      `SELECT DISTINCT sensor_id FROM gnss WHERE gnss_id = $1`,
      [gnssId]
    );

    const validSensorRegex = /^[A-Z]{3}0(1|2|5)$/;

    const filteredSensors = result.rows
      .map(row => row.sensor_id)
      .filter(sensorId => validSensorRegex.test(sensorId));

    res.json(filteredSensors);
  } catch (err) {
    console.error('Error fetching sensor IDs:', err);
    res.status(500).send('Error fetching sensor IDs');
  }
});

// Updated /api/gnss-detail endpoint with optional date filtering
app.get('/api/gnss-detail', async (req, res) => {
  const { gnssId, sensorId, startDate, endDate } = req.query;

  try {
    let query = `SELECT * FROM gnss WHERE gnss_id = $1 AND sensor_id = $2`;
    const params = [gnssId, sensorId];

    if (startDate) {
      params.push(startDate);
      query += ` AND timestamp >= $${params.length}`;
    }
    if (endDate) {
      params.push(endDate);
      query += ` AND timestamp <= $${params.length}`;
    }

    query += ` ORDER BY timestamp ASC`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching GNSS detail data:', err);
    res.status(500).send('Error fetching GNSS detail data');
  }
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});