from flask import session
from .database import DatabaseConnection
import datetime

class ShowModel:
    @staticmethod
    def get_shows_with_details(filters=None):
        cinema_id = session.get('cinema_id')
        if not cinema_id:
            raise ValueError("CinemaID not found in session")

        query = """
            SELECT 
                s.ScreeningID,
                s.MovieID,
                s.CinemaID,
                s.AuditoriumID,
                s.ShowDate,
                s.StartTime,
                m.Title AS MovieTitle,
                c.CinemaName,
                a.AuditoriumName,
                a.Type AS AudType,
                a.Capacity,

                -- Correct calculation using ScreeningID
                ISNULL((
                    SELECT SUM(t.SeatCount)
                    FROM ticket t
                    WHERE t.ScreeningID = s.ScreeningID
                ), 0) AS BookedSeats

            FROM showtime s
            INNER JOIN movie m ON s.MovieID = m.MovieID
            INNER JOIN cinema c ON s.CinemaID = c.CinemaID
            INNER JOIN auditorium a 
                ON s.CinemaID = a.CinemaID 
                AND s.AuditoriumID = a.AuditoriumID
            WHERE s.CinemaID = ?
        """
        params = [cinema_id]

        if filters:
            if filters.get('movie_id'):
                query += " AND s.MovieID = ?"
                params.append(filters['movie_id'])
            if filters.get('show_date'):
                query += " AND s.ShowDate = ?"
                params.append(filters['show_date'])

        query += " ORDER BY s.ShowDate, s.StartTime"

        return DatabaseConnection.execute_query(query, params)

    @staticmethod
    def create_show(data):
        """
        Insert into showtime with validation
        """
        cinema_id = session.get('cinema_id')
        if not cinema_id:
            return False, "Cinema not found in session"
        
        try:
            def normalize_time(time_str):
                """Convert HH:MM to HH:MM:SS if needed"""
                if len(time_str) == 5:  # Format: HH:MM
                    return f"{time_str}:00"
                return time_str
            
            show_date_str = data['show_date']
            start_time_str = normalize_time(data['start_time'])
            
            show_datetime_str = f"{show_date_str} {start_time_str}"
            show_datetime = datetime.datetime.strptime(show_datetime_str, '%Y-%m-%d %H:%M:%S')
            current_datetime = datetime.datetime.now()
            
        except ValueError as e:
            return False, f"Error: Date or time data format is incorrect. Details: {str(e)}"
        
        if show_datetime < current_datetime:
            return False, f"Error: The showtime ({show_datetime_str}) cannot be in the past."
        
        time_until_show = show_datetime - current_datetime
        if time_until_show.total_seconds() < 3600:  # 1 hour = 3600 seconds
            return False, f"Error: The showtime must be at least 1 hour from now. Current time: {current_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
        
        query = """
            INSERT INTO showtime (MovieID, CinemaID, AuditoriumID, ShowDate, StartTime)
            VALUES (?, ?, ?, ?, ?)
        """

        params = (
            data['movie_id'],
            cinema_id,
            data['auditorium_id'],
            show_date_str,
            start_time_str
        )

        try:
            DatabaseConnection.execute_query(query, params, fetch=False)
            return True, None
        except Exception as e:
            return False, f"Database error: {str(e)}"
        
    @staticmethod
    def update_show(old_keys, new_data):
        """
        Update logic for a showtime, with checks to prevent modifying past or imminent shows.
        old_keys = (movie_id, auditorium_id, old_show_date, old_start_time)
        new_data = { 'auditorium_id', 'show_date', 'start_time' }
        """
        cinema_id = session.get('cinema_id')
        if not cinema_id:
            return False, "Cinema not found in session"

        try:
            old_movie_id, old_auditorium_id, old_show_date_str, old_start_time_str = old_keys
            new_show_date_str = new_data['show_date']
            new_start_time_str = new_data['start_time']
            
            def normalize_time(time_str):
                """Convert HH:MM to HH:MM:SS if needed"""
                if len(time_str) == 5:  # Format: HH:MM
                    return f"{time_str}:00"
                return time_str
            
            old_start_time_str = normalize_time(old_start_time_str)
            new_start_time_str = normalize_time(new_start_time_str)
            
            old_show_datetime_str = f"{old_show_date_str} {old_start_time_str}"
            old_show_datetime = datetime.datetime.strptime(old_show_datetime_str, '%Y-%m-%d %H:%M:%S')

            new_show_datetime_str = f"{new_show_date_str} {new_start_time_str}"
            new_show_datetime = datetime.datetime.strptime(new_show_datetime_str, '%Y-%m-%d %H:%M:%S')
            
            current_datetime = datetime.datetime.now()

        except ValueError as e:
            return False, f"Error: Date or time data format is incorrect. Details: {str(e)}"

        if old_show_datetime < current_datetime:
            return False, f"Error: Cannot modify showtime. The original showtime ({old_show_datetime_str}) has already passed."

        time_until_show = old_show_datetime - current_datetime
        if time_until_show.total_seconds() < 7200:  # 2 hours = 7200 seconds
            return False, f"Error: Cannot modify showtime. The original showtime starts too soon (within 2 hours). Show time: {old_show_datetime_str}"
        
        if new_show_datetime < current_datetime:
            return False, f"Error: The new showtime ({new_show_datetime_str}) cannot be in the past."
        
        time_until_new_show = new_show_datetime - current_datetime
        if time_until_new_show.total_seconds() < 3600:  # 1 hour = 3600 seconds
            return False, f"Error: The new showtime must be at least 1 hour from now. Current time: {current_datetime.strftime('%Y-%m-%d %H:%M:%S')}"

        ticket_count_query = """
            SELECT COUNT(*)
            FROM ticket t
            INNER JOIN showtime s ON t.ScreeningID = s.ScreeningID
            WHERE s.MovieID = ?
            AND s.CinemaID = ?
            AND s.AuditoriumID = ?
            AND s.ShowDate = ?
            AND s.StartTime = ?
        """
        
        ticket_count = DatabaseConnection.execute_scalar(
            ticket_count_query,
            (old_movie_id, cinema_id, old_auditorium_id, old_show_date_str, old_start_time_str)
        )

        if ticket_count > 0:
            return False, "Cannot modify this showtime because tickets have already been purchased."
        
        delete_query = """
            DELETE FROM showtime
            WHERE MovieID = ? AND CinemaID = ? AND AuditoriumID = ?
            AND ShowDate = ? AND StartTime = ?
        """

        insert_query = """
            INSERT INTO showtime (MovieID, CinemaID, AuditoriumID, ShowDate, StartTime)
            VALUES (?, ?, ?, ?, ?)
        """

        try:
            DatabaseConnection.execute_query(
                delete_query,
                (old_movie_id, cinema_id, old_auditorium_id, old_show_date_str, old_start_time_str),
                fetch=False
            )

            DatabaseConnection.execute_query(
                insert_query,
                (
                    old_movie_id,
                    cinema_id,
                    new_data['auditorium_id'],
                    new_data['show_date'],
                    new_data['start_time']
                ),
                fetch=False
            )

            return True, None

        except Exception as e:
            return False, f"Database error (Overlap Check Failed or other issue): {str(e)}"    
            
    @staticmethod
    def delete_show(movie_id, auditorium_id, show_date, start_time):
        cinema_id = session.get('cinema_id')
        if not cinema_id:
            return False, "Cinema not found in session"

        try:
            def normalize_time(time_str):
                """Convert HH:MM to HH:MM:SS if needed"""
                if len(time_str) == 5:  # Format: HH:MM
                    return f"{time_str}:00"
                return time_str
            
            start_time_normalized = normalize_time(start_time)
            
            show_datetime_str = f"{show_date} {start_time_normalized}"
            show_datetime = datetime.datetime.strptime(show_datetime_str, '%Y-%m-%d %H:%M:%S')
            current_datetime = datetime.datetime.now()
            
        except ValueError as e:
            return False, f"Error: Date or time data format is incorrect. Details: {str(e)}"
        
        if show_datetime < current_datetime:
            return False, f"Error: Cannot delete showtime. The showtime ({show_datetime_str}) has already passed."
        
        time_until_show = show_datetime - current_datetime
        if time_until_show.total_seconds() < 7200:  # 2 hours = 7200 seconds
            return False, f"Error: Cannot delete showtime. The showtime starts too soon (within 2 hours). Show time: {show_datetime_str}"

        ticket_count_query = """
            SELECT COUNT(*)
            FROM ticket t
            INNER JOIN showtime s ON t.ScreeningID = s.ScreeningID
            WHERE s.MovieID = ?
            AND s.CinemaID = ?
            AND s.AuditoriumID = ?
            AND s.ShowDate = ?
            AND s.StartTime = ?
        """

        ticket_count = DatabaseConnection.execute_scalar(
            ticket_count_query,
            (movie_id, cinema_id, auditorium_id, show_date, start_time_normalized)
        )

        if ticket_count and ticket_count > 0:
            return False, "Cannot delete this showtime because tickets have already been purchased."

        try:
            conn = DatabaseConnection.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                DELETE FROM showtime
                WHERE MovieID = ? AND CinemaID = ? AND AuditoriumID = ?
                AND ShowDate = ? AND StartTime = ?
            """, (movie_id, cinema_id, auditorium_id, show_date, start_time_normalized))

            conn.commit()
            return True, None

        except Exception as e:
            try:
                conn.rollback()
            except:
                pass
            return False, f"Database error: {str(e)}"

        finally:
            conn.close()

    @staticmethod
    def get_show_by_id(movie_id, auditorium_id, show_date, start_time):
        cinema_id = session.get('cinema_id')
        if not cinema_id:
            raise ValueError("Cinema not found in session")

        query = """
            SELECT 
                s.ScreeningID,
                s.MovieID,
                s.CinemaID,
                s.AuditoriumID,
                s.ShowDate,
                s.StartTime,
                m.Title,
                m.DurationMin,
                c.CinemaName,
                a.AuditoriumName,
                c.Address,
                a.Capacity,

                ISNULL((
                    SELECT SUM(t.SeatCount)
                    FROM ticket t
                    WHERE t.ScreeningID = s.ScreeningID
                ), 0) AS BookedSeats

            FROM showtime s
            INNER JOIN movie m ON s.MovieID = m.MovieID
            INNER JOIN cinema c ON s.CinemaID = c.CinemaID
            INNER JOIN auditorium a
                ON s.CinemaID = a.CinemaID
                AND s.AuditoriumID = a.AuditoriumID
            WHERE s.MovieID = ?
            AND s.CinemaID = ?
            AND s.AuditoriumID = ?
            AND s.ShowDate = ?
            AND s.StartTime = ?
        """

        return DatabaseConnection.execute_query(
            query, (movie_id, cinema_id, auditorium_id, show_date, start_time)
        )

    @staticmethod
    def get_showtimes_by_movie(movie_id):
        """
        Get all showtimes for a specific movie (only future showtimes)
        """
        query = """
            SELECT
                s.ShowDate,
                s.StartTime,
                c.CinemaID,
                c.CinemaName,
                c.City,
                c.District,
                a.AuditoriumID,
                a.AuditoriumName,
                a.Type AS AuditoriumType
            FROM showtime s
            JOIN cinema c ON s.CinemaID = c.CinemaID
            JOIN auditorium a 
                ON s.CinemaID = a.CinemaID
                AND s.AuditoriumID = a.AuditoriumID
            WHERE s.MovieID = ?
            AND DATEADD(SECOND, DATEDIFF(SECOND, '00:00:00', s.StartTime), 
                        CAST(s.ShowDate AS DATETIME)) > GETDATE()
            ORDER BY s.ShowDate, c.City, c.CinemaName, s.StartTime
        """

        columns, rows = DatabaseConnection.execute_query(query, (movie_id,))
        return [dict(zip(columns, r)) for r in rows]

    @staticmethod
    def get_seats(cinema_id, auditorium_id):
        query = """
            SELECT SeatNumber, SeatType
            FROM seat
            WHERE CinemaID = ? AND AuditoriumID = ?
            ORDER BY SeatNumber
        """

        columns, rows = DatabaseConnection.execute_query(query, (cinema_id, auditorium_id))
        return [dict(zip(columns, r)) for r in rows]

    @staticmethod
    def get_booked_seats(cinema_id, auditorium_id, show_date, start_time):
        screening_query = """
            SELECT ScreeningID
            FROM showtime
            WHERE CinemaID = ? AND AuditoriumID = ? AND ShowDate = ? AND StartTime = ?
        """

        result = DatabaseConnection.execute_query(
            screening_query,
            (cinema_id, auditorium_id, show_date, start_time)
        )

        columns, rows = result

        if not rows:
            return []  # No show found

        screening_id = rows[0][0]

        booked_query = """
            SELECT sb.SeatNumber
            FROM seat_booking sb
            JOIN ticket t ON sb.TicketID = t.TicketID
            WHERE t.ScreeningID = ?
            ORDER BY sb.SeatNumber
        """

        _, booked_rows = DatabaseConnection.execute_query(booked_query, (screening_id,))
        return [r[0] for r in booked_rows]
