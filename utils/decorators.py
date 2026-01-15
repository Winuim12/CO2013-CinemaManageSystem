from functools import wraps
from flask import session, redirect, url_for, flash

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
            if 'logged_in' not in session:
                flash('Please log in to access this page.', 'warning')
                return redirect(url_for('auth.login'))
            return f(*args, **kwargs)
    return decorated_function

def manager_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('auth.login'))
        if session.get('role') != 'manager':
            flash('Manager role required!', 'danger')
            return redirect(url_for('auth.choose_role'))
        return f(*args, **kwargs)
    return decorated_function

def customer_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('auth.login'))
        if session.get('role') != 'customer':
            flash('Customer role required!', 'danger')
            return redirect(url_for('auth.choose_role'))
        return f(*args, **kwargs)
    return decorated_function
