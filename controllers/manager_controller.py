from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from utils.decorators import login_required, manager_required
from models.movie_model import MovieModel
from models.show_model import ShowModel
from models.report_model import ReportModel
from datetime import datetime
from models.database import DatabaseConnection

manager_bp = Blueprint('manager', __name__)


@manager_bp.route('/')
@login_required
@manager_required
def dashboard():
    return render_template('manager/dashboard.html')

# Shows list
@manager_bp.route('/shows')
@login_required
@manager_required
def shows():
    filters = {k: v for k, v in {
        'movie_id': request.args.get('movie_id'),
        'show_date': request.args.get('show_date')
    }.items() if v}
    
    columns, shows_data = ShowModel.get_shows_with_details(filters)
    _, movies_list = MovieModel.get_all_movies()
    return render_template('manager/shows.html', columns=columns, shows=shows_data,
                           movies=movies_list, filters=filters)

# New show
@manager_bp.route('/show/new', methods=['GET', 'POST'])
@login_required
@manager_required
def show_new():
    cinema_id = session.get('cinema_id')
    if not cinema_id:
        flash("Cinema not found in session", "danger")
        return redirect(url_for('manager.shows'))

    _, movies_list = MovieModel.get_all_movies()
    _, auditoriums_list = DatabaseConnection.execute_query(
        "SELECT AuditoriumID, AuditoriumName, Type, Capacity FROM auditorium WHERE CinemaID = ?",
        (cinema_id,)
    )
    if request.method == 'POST':
        try:
            data = {
                'movie_id': int(request.form.get('movie_id')),
                'auditorium_id': int(request.form.get('auditorium_id')),
                'show_date': request.form.get('show_date'),
                'start_time': request.form.get('start_time'),
                'cinema_id': cinema_id  
            }

            success, error_msg = ShowModel.create_show(data)
            if success:
                flash('Show created successfully!', 'success')
                return redirect(url_for('manager.shows'))

            flash(f'Error creating show: {error_msg}', 'danger')
        except Exception as e:
            flash(f'Unexpected error: {str(e)}', 'danger')

    return render_template(
        'manager/show_form.html',
        movies=movies_list,
        auditoriums=auditoriums_list,
        show=None  
    )

# Show details
@manager_bp.route('/show/detail')
@login_required
@manager_required
def show_detail():
    movie_id = request.args.get('movie_id', type=int)
    auditorium_id = request.args.get('auditorium_id', type=int)
    show_date = request.args.get('show_date')
    start_time = request.args.get('start_time')

    columns, data = ShowModel.get_show_by_id(movie_id, auditorium_id, show_date, start_time)

    if not data:
        flash("Show not found", "danger")
        return redirect(url_for('manager.shows'))

    show = dict(zip(columns, data[0]))
    return render_template("manager/show_detail.html", show=show)

@manager_bp.route('/show/edit', methods=['GET', 'POST'])
@login_required
@manager_required
def show_edit():
    movie_id = request.args.get('movie_id')
    auditorium_id = request.args.get('auditorium_id')
    show_date = request.args.get('show_date')
    start_time = request.args.get('start_time')

    old_keys = (movie_id, auditorium_id, show_date, start_time)
    cinema_id = session.get('cinema_id')

    if request.method == 'POST':
        new_data = {
            'movie_id': movie_id,          
            'auditorium_id': request.form.get('auditorium_id'),
            'show_date': request.form.get('show_date'),
            'start_time': request.form.get('start_time')
        }

        success, error_msg = ShowModel.update_show(old_keys, new_data)
        if success:
            flash("Show updated successfully!", "success")
            return redirect(url_for('manager.shows'))
        flash(f"Error updating show: {error_msg}", "danger")

    columns, data = ShowModel.get_show_by_id(movie_id, auditorium_id, show_date, start_time)
    if not data:
        flash("Show not found", "danger")
        return redirect(url_for('manager.shows'))
    show = dict(zip(columns, data[0]))

    _, auditoriums_list = DatabaseConnection.execute_query(
        "SELECT AuditoriumID, AuditoriumName, Type, Capacity FROM auditorium WHERE CinemaID = ?",
        (cinema_id,)
    )

    return render_template(
        "manager/show_form.html",
        show=show,
        auditoriums=auditoriums_list
    )

# Delete show
@manager_bp.route('/show/delete', methods=['POST'])
@login_required
@manager_required
def show_delete():
    movie_id = request.form.get('movie_id')
    auditorium_id = request.form.get('auditorium_id')
    show_date = request.form.get('show_date')
    start_time = request.form.get('start_time')

    success, error_msg = ShowModel.delete_show(movie_id, auditorium_id, show_date, start_time)

    if success:
        flash('Show deleted successfully!', 'success')
    else:
        flash(f'Error deleting show: {error_msg}', 'danger')

    return redirect(url_for('manager.shows'))

@manager_bp.route('/report/monthly')
@login_required
@manager_required
def monthly_report():
    cinema_id = session.get('cinema_id')
    if not cinema_id:
        flash("Cinema not found in session", "danger")
        return redirect(url_for('manager.dashboard'))  

    month = int(request.args.get('month', datetime.now().month))
    year = int(request.args.get('year', datetime.now().year))
    min_revenue = float(request.args.get('min_revenue', 0.0))

    data_list = ReportModel.get_monthly_revenue_all(cinema_id, month, year, min_revenue)

    return render_template(
        'manager/monthly_report.html',
        cinema_id=cinema_id,
        month=month,
        year=year,
        min_revenue=min_revenue,
        data_list=data_list
    )