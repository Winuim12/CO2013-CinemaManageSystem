from flask import Blueprint, render_template, request, session, url_for, redirect, flash
from utils.decorators import login_required, customer_required
from models.show_model import ShowModel
from models.movie_model import MovieModel
from models.database import DatabaseConnection

customer_bp = Blueprint('customer', __name__)

@customer_bp.route('/')
@login_required
@customer_required
def dashboard():
    return render_template('customer/home.html')

@customer_bp.route('/my_tickets')
@login_required
@customer_required
def my_tickets():
    customer_id = session.get('customer_id')

    if customer_id is None:
        return redirect(url_for('auth.select_customer'))

    customer_id = int(customer_id)

    query = """
        SELECT 
            t.TicketID,
            m.Title AS MovieName,
            c.CinemaName,
            a.AuditoriumName,
            a.Type AS AuditoriumType,
            s.AuditoriumID,
            s.ShowDate,
            s.StartTime,
            t.PriceTotal,
            STRING_AGG(CAST(sb.SeatNumber AS VARCHAR(10)), ', ') AS Seats
        FROM ticket t
        JOIN showtime s
            ON t.ScreeningID = s.ScreeningID
        JOIN movie m
            ON s.MovieID = m.MovieID
        JOIN cinema c
            ON s.CinemaID = c.CinemaID
        JOIN auditorium a
            ON a.CinemaID = s.CinemaID
            AND a.AuditoriumID = s.AuditoriumID
        LEFT JOIN seat_booking sb
            ON t.TicketID = sb.TicketID
        WHERE t.CustomerID = ?
        GROUP BY 
            t.TicketID,
            m.Title, 
            c.CinemaName,
            a.AuditoriumName,
            a.Type,
            s.AuditoriumID,
            s.ShowDate,
            s.StartTime,
            t.PriceTotal
        ORDER BY t.TicketID DESC;
    """

    columns, rows = DatabaseConnection.execute_query(query, (customer_id,))

    tickets = []
    for r in rows:
        tickets.append({
            "TicketID": r[0],
            "MovieName": r[1],
            "CinemaName": r[2],
            "AuditoriumName": r[3],
            "AuditoriumType": r[4],
            "AuditoriumID": r[5],
            "ShowDate": r[6],
            "StartTime": r[7],
            "PriceTotal": float(r[8]),
            "Seats": r[9].split(', ') if r[9] else []
        })

    return render_template("customer/my_tickets.html", tickets=tickets)

@customer_bp.route('/movies')
@login_required
@customer_required
def movies():
    columns, rows = MovieModel.get_all_movies() 

    movies = []
    for r in rows:
        movies.append({
            "MovieID": r[0],
            "Title": r[1],
            "Classification": r[2],
            "DurationMin": r[3],
            "Rating": r[4],
            "Status": r[5],
            "ReleaseDate": r[6],
            "Language": r[7],
            "ImageFile": r[8],
            "Genres": r[9]
        })

    return render_template('customer/select_movie.html', movies=movies)

@customer_bp.route('/movie/<int:movie_id>/showtimes')
@login_required
@customer_required
def showtimes(movie_id):

    movie = MovieModel.get_movie_by_id(movie_id)

    showtimes = ShowModel.get_showtimes_by_movie(movie_id)

    grouped = {}

    for st in showtimes:
        date = st["ShowDate"]
        city = st["City"]
        cinema = st["CinemaName"]

        if date not in grouped:
            grouped[date] = {}

        if city not in grouped[date]:
            grouped[date][city] = {}

        if cinema not in grouped[date][city]:
            grouped[date][city][cinema] = []

        grouped[date][city][cinema].append({
            "AuditoriumID": st["AuditoriumID"],
            "CinemaID": st["CinemaID"],      
            "StartTime": st["StartTime"],
            "CinemaName": st["CinemaName"],
            "AuditoriumType": st["AuditoriumType"]
        })

    return render_template(
        "customer/select_showtime.html",
        movie=movie,
        grouped_showtimes=grouped
    )

@customer_bp.route('/select_seat')
@login_required
@customer_required
def select_seats():
    movie_id = request.args.get("movie_id", type=int)
    cinema_id = request.args.get("cinema_id", type=int)
    auditorium_id = request.args.get("auditorium_id", type=int)
    show_date = request.args.get("show_date")
    start_time = request.args.get("start_time")
    auditorium_type = request.args.get("auditorium_type")
    cinema_name = request.args.get("cinema_name")

    if not (movie_id and cinema_id and auditorium_id and show_date and start_time):
        return "Missing parameters", 400

    seats = ShowModel.get_seats(cinema_id, auditorium_id)
    booked_seats = ShowModel.get_booked_seats(cinema_id, auditorium_id, show_date, start_time)

    return render_template(
        'customer/select_seats.html',
        seats=seats,
        booked=booked_seats,
        movie_id=movie_id,
        cinema_id=cinema_id,
        auditorium_id=auditorium_id,
        show_date=show_date,
        start_time=start_time,
        auditorium_type=auditorium_type,
        cinema_name = cinema_name
    )

@customer_bp.route('/select_discount', methods=['POST'])
@login_required
@customer_required
def discount():
    if "customer_id" not in session:
        flash("Please log in first.", "danger")
        return redirect(url_for("customer.login"))

    customer_id = session["customer_id"]

    movie_id = request.form.get("movie_id", type=int)
    cinema_id = request.form.get("cinema_id", type=int)
    auditorium_id = request.form.get("auditorium_id", type=int)
    show_date = request.form.get("show_date")
    start_time = request.form.get("start_time")
    selected_seats = request.form.getlist("selected_seats")
    cinema_name = request.form.get("cinema_name")
    auditorium_type = request.form.get("auditorium_type")
    movie = MovieModel.get_movie_by_id(movie_id)
    columns, discount_rows = DatabaseConnection.execute_query("""
        SELECT d.DiscountID,
               d.DiscountCode,
               d.DiscountType,
               d.DiscountValue,
               d.ExpiryDate,
               od.Quantity
        FROM own_discount od
        JOIN discount d ON d.DiscountID = od.DiscountID
        WHERE od.CustomerID = ?
    """, [customer_id])

    return render_template(
        "customer/select_discount.html",
        movie=movie,
        cinema_id=cinema_id,
        auditorium_id=auditorium_id,
        show_date=show_date,
        start_time=start_time,
        selected_seats=selected_seats,
        discounts=discount_rows,
        cinema_name=cinema_name,
        auditorium_type=auditorium_type
    )

@customer_bp.route('/review_booking', methods=['POST'])
@login_required
@customer_required
def review_booking():
    if "customer_id" not in session:
        flash("Please log in first.", "danger")
        return redirect(url_for("customer.login"))
    customer_id = session["customer_id"]
    
    cinema_id = request.form.get("cinema_id", type=int)
    auditorium_id = request.form.get("auditorium_id", type=int)
    show_date = request.form.get("show_date")
    start_time = request.form.get("start_time")
    movie_id = request.form.get("movie_id", type=int)
    cinema_name = request.form.get("cinema_name")
    auditorium_type = request.form.get("auditorium_type")
    
    selected_seats_raw = request.form.getlist("selected_seats")
    if not selected_seats_raw:
        selected_seats_raw = request.form.get("selected_seats", "")
        if selected_seats_raw:
            selected_seats_raw = [selected_seats_raw]
    
    selected_seats = []
    for seat in selected_seats_raw:
        if ',' in str(seat):
            selected_seats.extend([int(s.strip()) for s in str(seat).split(',') if s.strip()])
        elif seat:
            selected_seats.append(int(seat))
    
    discount_ids_raw = request.form.getlist("discount_ids")
    discount_ids = []
    for disc in discount_ids_raw:
        if disc:
            discount_ids.append(int(disc))
    
    if not selected_seats:
        flash("Please select at least one seat.", "danger")
        return redirect(request.referrer)
    
    movie = MovieModel.get_movie_by_id(movie_id)
    
    placeholders = ",".join("?" for _ in selected_seats)
    query = f"""
        SELECT SeatNumber, SeatType
        FROM seat
        WHERE CinemaID = ? AND AuditoriumID = ? AND SeatNumber IN ({placeholders})
    """
    columns, rows = DatabaseConnection.execute_query(query, [cinema_id, auditorium_id] + selected_seats)
    
    seats_info = []
    total_price = 0
    for seat in rows:
        seat_number = seat[0]
        seat_type = seat[1]
        price = 100000 if seat_type == "VIP" else 80000
        total_price += price
        seats_info.append({
            'number': seat_number,
            'type': seat_type,
            'price': price
        })
    
    discounts_info = []
    total_discount = 0
    
    if discount_ids:
        for discount_id in discount_ids:
            columns, disc_rows = DatabaseConnection.execute_query("""
                SELECT d.DiscountCode, d.DiscountValue, d.DiscountType, od.Quantity
                FROM own_discount od
                JOIN discount d ON d.DiscountID = od.DiscountID
                WHERE od.CustomerID = ? AND od.DiscountID = ?
            """, [customer_id, discount_id])
            
            if disc_rows and disc_rows[0][3] > 0:
                discount_value = float(disc_rows[0][1])
                total_discount += discount_value
                discounts_info.append({
                    'id': discount_id,
                    'code': disc_rows[0][0],
                    'value': discount_value,
                    'type': disc_rows[0][2]
                })
    
    final_price = max(total_price - total_discount, 0)
    
    return render_template(
        "customer/review_booking.html",
        movie=movie,
        cinema_name=cinema_name,
        cinema_id=cinema_id,
        auditorium_id=auditorium_id,
        show_date=show_date,
        start_time=start_time,
        seats=seats_info,
        discounts=discounts_info,
        total_price=total_price,
        total_discount=total_discount,
        final_price=final_price,
        selected_seats=selected_seats,
        discount_ids=discount_ids,
        auditorium_type=auditorium_type
    )

@customer_bp.route('/confirm_payment', methods=['POST'])
@login_required
@customer_required
def confirm_payment():
    if "customer_id" not in session:
        flash("Please log in first.", "danger")
        return redirect(url_for("customer.login"))
    customer_id = session["customer_id"]
    
    cinema_id = request.form.get("cinema_id", type=int)
    auditorium_id = request.form.get("auditorium_id", type=int)
    show_date = request.form.get("show_date")
    start_time = request.form.get("start_time")
    
    selected_seats_raw = request.form.getlist("selected_seats")
    if not selected_seats_raw:
        selected_seats_raw = request.form.get("selected_seats", "")
        if selected_seats_raw:
            selected_seats_raw = [selected_seats_raw]
    
    selected_seats = []
    for seat in selected_seats_raw:
        if ',' in str(seat):
            selected_seats.extend([int(s.strip()) for s in str(seat).split(',') if s.strip()])
        elif seat:
            selected_seats.append(int(seat))
    
    discount_ids_raw = request.form.getlist("discount_ids")
    discount_ids = []
    for disc in discount_ids_raw:
        if disc:
            discount_ids.append(int(disc))
    
    if not selected_seats:
        flash("Please select at least one seat.", "danger")
        return redirect(url_for("customer.now_showing"))
    
    screening_query = """
        SELECT ScreeningID
        FROM showtime
        WHERE CinemaID = ? AND AuditoriumID = ? AND ShowDate = ? AND StartTime = ?
    """
    columns, screening_rows = DatabaseConnection.execute_query(
        screening_query, 
        [cinema_id, auditorium_id, show_date, start_time]
    )
    
    if not screening_rows:
        flash("Showtime not found. Please try again.", "danger")
        return redirect(url_for("customer.now_showing"))
    
    screening_id = screening_rows[0][0]
    
    placeholders = ",".join("?" for _ in selected_seats)
    query = f"""
        SELECT SeatNumber, SeatType
        FROM seat
        WHERE CinemaID = ? AND AuditoriumID = ? AND SeatNumber IN ({placeholders})
    """
    columns, rows = DatabaseConnection.execute_query(query, [cinema_id, auditorium_id] + selected_seats)
    
    total_price = 0
    for seat in rows:
        seat_type = seat[1]
        if seat_type == "VIP":
            total_price += 100000
        else:
            total_price += 80000
    
    total_discount = 0
    valid_discount_ids = []
    
    if discount_ids:
        for discount_id in discount_ids:
            columns, disc_rows = DatabaseConnection.execute_query("""
                SELECT DiscountValue, Quantity
                FROM own_discount od
                JOIN discount d ON d.DiscountID = od.DiscountID
                WHERE od.CustomerID = ? AND od.DiscountID = ?
            """, [customer_id, discount_id])
            
            if disc_rows and disc_rows[0][1] > 0:
                discount_value = float(disc_rows[0][0])
                total_discount += discount_value
                valid_discount_ids.append(discount_id)
    
    total_price -= total_discount
    total_price = max(total_price, 0)
    
    try:
        ticket_id = DatabaseConnection.execute_insert_with_id("""
            INSERT INTO ticket (CustomerID, ScreeningID, PriceTotal, SeatCount)
            VALUES (?, ?, ?, ?)
        """, [customer_id, screening_id, total_price, len(selected_seats)])
        
    except Exception as e:
        print(f"Booking error: {str(e)}")
        flash("An error occurred while processing your booking. Please try again.", "danger")
        return redirect(url_for("customer.now_showing"))

    for seat_number in selected_seats:
        DatabaseConnection.execute_query("""
            INSERT INTO seat_booking (TicketID, SeatNumber, CinemaID, AuditoriumID)
            VALUES (?, ?, ?, ?)
        """, [ticket_id, seat_number, cinema_id, auditorium_id], fetch=False)
    
    for discount_id in valid_discount_ids:
        DatabaseConnection.execute_query("""
            INSERT INTO apply_discount (DiscountID, TicketID)
            VALUES (?, ?)
        """, [discount_id, ticket_id], fetch=False)

    flash("Booking confirmed!", "success")
    return redirect(url_for("customer.booking_confirmation", ticket_id=ticket_id))

@customer_bp.route('/booking_confirmation/<int:ticket_id>')
@login_required
@customer_required
def booking_confirmation(ticket_id):
    customer_id = session["customer_id"]

    columns, ticket_rows = DatabaseConnection.execute_query("""
        SELECT 
            t.TicketID, 
            t.PriceTotal, 
            t.SeatCount, 
            s.ShowDate, 
            s.StartTime,
            c.CinemaName, 
            a.AuditoriumName, 
            m.Title
        FROM ticket t
        JOIN showtime s ON t.ScreeningID = s.ScreeningID
        JOIN cinema c ON s.CinemaID = c.CinemaID
        JOIN auditorium a ON s.CinemaID = a.CinemaID AND s.AuditoriumID = a.AuditoriumID
        JOIN movie m ON s.MovieID = m.MovieID
        WHERE t.TicketID = ? AND t.CustomerID = ?
    """, [ticket_id, customer_id])

    if not ticket_rows:
        flash("Ticket not found.", "danger")
        return redirect(url_for("customer.now_showing"))

    ticket = ticket_rows[0]

    columns, seats_rows = DatabaseConnection.execute_query("""
        SELECT SeatNumber 
        FROM seat_booking
        WHERE TicketID = ?
        ORDER BY SeatNumber
    """, [ticket_id])

    booked_seats = [row[0] for row in seats_rows]

    columns, discount_rows = DatabaseConnection.execute_query("""
        SELECT d.DiscountCode, d.DiscountValue, d.DiscountType
        FROM apply_discount ad
        JOIN discount d ON ad.DiscountID = d.DiscountID
        WHERE ad.TicketID = ?
        ORDER BY d.DiscountCode
    """, [ticket_id])

    discounts = []
    total_discount_value = 0
    for row in discount_rows:
        discount = {
            'DiscountCode': row[0],
            'DiscountValue': float(row[1]),
            'DiscountType': row[2]
        }
        discounts.append(discount)
        total_discount_value += float(row[1])

    return render_template(
        "customer/booking_confirmation.html",
        ticket=ticket,
        seats=booked_seats,
        discounts=discounts,
        total_discount=total_discount_value
    )