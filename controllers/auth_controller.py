from flask import Blueprint, render_template, request, redirect, url_for, session, flash
from config import DB_CONFIG
from models.database import DatabaseConnection
from functools import wraps

auth_bp = Blueprint('auth', __name__)

def login_required(f):
    """Decorator to check if user is logged in"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            flash('Please log in first.', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

def role_required(f):
    """Decorator to check if user has selected a role and specific ID"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            flash('Please log in first.', 'warning')
            return redirect(url_for('auth.login'))

        role = session.get('role')
        if not role:
            flash('Please select a role first.', 'warning')
            return redirect(url_for('auth.choose_role'))

        if role == 'manager' and 'manager_id' not in session:
            flash('Please select a manager profile first.', 'warning')
            return redirect(url_for('auth.select_manager'))
        elif role == 'customer' and 'customer_id' not in session:
            flash('Please select a customer profile first.', 'warning')
            return redirect(url_for('auth.select_customer'))

        return f(*args, **kwargs)
    return decorated_function

@auth_bp.route('/')
def index():
    if 'logged_in' in session:
        return redirect(url_for('auth.dashboard'))
    return redirect(url_for('auth.login'))

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        if username == DB_CONFIG['username'] and password == DB_CONFIG['password']:
            session['logged_in'] = True
            session['username'] = username
            flash('Login successful!', 'success')
            return redirect(url_for('auth.choose_role'))
        else:
            flash('Invalid username or password', 'danger')
    return render_template('login.html')

@auth_bp.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'info')
    return redirect(url_for('auth.login'))

@auth_bp.route('/choose-role', methods=['GET', 'POST'])
@login_required
def choose_role():
    if request.method == 'POST':
        selected_role = request.form.get('role')
        if selected_role not in ['manager', 'customer']:
            flash('Invalid role selected!', 'danger')
            return render_template('choose_role.html')

        session['role'] = selected_role

        session.pop('manager_id', None)
        session.pop('cinema_id', None)
        session.pop('manager_username', None)
        session.pop('customer_id', None)
        session.pop('customer_name', None)

        if selected_role == 'manager':
            return redirect(url_for('auth.select_manager'))
        else:
            return redirect(url_for('auth.select_customer'))

    return render_template('choose_role.html')

@auth_bp.route('/select-manager', methods=['GET', 'POST'])
@login_required
def select_manager():
    if session.get('role') != 'manager':
        flash('Please select manager role first.', 'warning')
        return redirect(url_for('auth.choose_role'))

    if request.method == 'POST':
        val = request.form.get('selected_manager') 
        if val:
            manager_id, cinema_id, manager_name = val.split('|')

            session.pop('manager_id', None)
            session.pop('cinema_id', None)
            session.pop('manager_username', None)

            session['manager_id'] = manager_id
            session['cinema_id'] = cinema_id
            session['manager_username'] = manager_name

            flash('Manager selected successfully!', 'success')
            return redirect(url_for('manager.dashboard'))
        else:
            flash('Please select a manager.', 'danger')

    try:
        query = """
        SELECT DISTINCT
            m.ManagerID,
            u.Username,
            u.Email,
            u.Phone,
            c.CinemaID,
            c.CinemaName,
            c.City,
            c.District,
            c.Address
        FROM manage m
        INNER JOIN staff s ON m.ManagerID = s.StaffID
        INNER JOIN user_account u ON s.StaffID = u.UserID
        INNER JOIN cinema c ON s.CinemaID = c.CinemaID
        ORDER BY c.CinemaName, u.Username;
        """
        columns, rows = DatabaseConnection.execute_query(query)

        managers = [
            {
                'ManagerID': row[0],
                'Username': row[1],
                'Email': row[2],
                'Phone': row[3],
                'CinemaID': row[4],       
                'CinemaName': row[5],
                'City': row[6],
                'District': row[7],
                'Address': row[8]
            }
            for row in rows
        ]

        return render_template('select_manager.html', managers=managers)

    except Exception as e:
        flash(f'Error loading managers: {str(e)}', 'danger')
        return redirect(url_for('auth.choose_role'))

@auth_bp.route('/select-customer', methods=['GET', 'POST'])
@login_required
def select_customer():
    if session.get('role') != 'customer':
        flash('Please select customer role first.', 'warning')
        return redirect(url_for('auth.choose_role'))

    if request.method == 'POST':
        val = request.form.get('selected_customer')  
        if val:
            customer_id, customer_name = val.split('|')

            session.pop('customer_id', None)
            session.pop('customer_name', None)

            session['customer_id'] = customer_id
            session['customer_name'] = customer_name

            flash('Customer selected successfully!', 'success')
            return redirect(url_for('customer.dashboard'))
        else:
            flash('Please select a customer', 'danger')

    try:
        query = """
        SELECT 
            c.CustomerID,
            u.Username,
            u.Email,
            u.Phone,
            u.City,
            u.District,
            COALESCE(m.Status, 'No Membership') AS MembershipStatus,
            m.CardNo,
            m.RegisterDate
        FROM customer c
        INNER JOIN user_account u ON c.CustomerID = u.UserID
        LEFT JOIN membership m ON c.CustomerID = m.CustomerID
        ORDER BY u.Username
        """
        columns, rows = DatabaseConnection.execute_query(query)

        customer_list = []
        for row in rows:
            customer_list.append({
                'CustomerID': row[0],
                'Username': row[1],
                'Email': row[2],
                'Phone': row[3],
                'City': row[4],
                'District': row[5],
                'MembershipStatus': row[6],
                'CardNo': row[7] if row[7] else 'N/A',
                'RegisterDate': row[8].strftime('%Y-%m-%d') if row[8] else 'N/A'
            })

        return render_template('select_customer.html', customers=customer_list)

    except Exception as e:
        flash(f'Error loading customers: {str(e)}', 'danger')
        return redirect(url_for('auth.choose_role'))

@auth_bp.route('/dashboard')
@login_required
def dashboard():
    role = session.get('role')

    if not role:
        return redirect(url_for('auth.choose_role'))

    if role == 'manager':
        if 'manager_id' not in session:
            flash('Please select a manager profile first.', 'warning')
            return redirect(url_for('auth.select_manager'))
        return redirect(url_for('manager.dashboard'))

    elif role == 'customer':
        if 'customer_id' not in session:
            flash('Please select a customer profile first.', 'warning')
            return redirect(url_for('auth.select_customer'))
        return redirect(url_for('customer.dashboard'))

    return redirect(url_for('auth.choose_role'))

@auth_bp.app_context_processor
def inject_role_status():
    role = session.get('role')
    role_complete = False

    if role == 'manager' and 'manager_id' in session:
        role_complete = True
    elif role == 'customer' and 'customer_id' in session:
        role_complete = True

    return dict(role_complete=role_complete)
