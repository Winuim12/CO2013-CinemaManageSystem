from .database import DatabaseConnection

class MovieModel:
    @staticmethod
    def get_all_movies():
        """
        Fetch all movies with their genres.
        Each row returned:
        (MovieID, Title, Classification, DurationMin, Rating, Status, ReleaseDate, Language, Genres)
        """
        query = """
            SELECT 
                m.MovieID,
                m.Title,
                m.Classification,
                m.DurationMin,
                m.Rating,
                m.Status,
                m.ReleaseDate,
                m.Language,
                m.ImageFile,
                STRING_AGG(mg.Genre, ', ') AS Genres
            FROM movie m
            LEFT JOIN movie_genre mg ON m.MovieID = mg.MovieID
            GROUP BY 
                m.MovieID, m.Title, m.Classification, m.DurationMin, m.Rating,
                m.Status, m.ReleaseDate, m.Language, m.ImageFile
            ORDER BY m.Title;
        """
        try:
            columns, rows = DatabaseConnection.execute_query(query)
            return columns, rows
        except Exception as e:
            print(f"Error fetching movies: {e}")
            return [], []
    @staticmethod
    def get_movie_by_id(movie_id):
        query = """
            SELECT 
                m.MovieID,
                m.Title,
                m.Classification,
                m.DurationMin,
                m.Rating,
                m.Status,
                m.ReleaseDate,
                m.Language,
                STRING_AGG(g.Genre, ', ') AS Genres
            FROM movie m
            LEFT JOIN movie_genre g
                ON m.MovieID = g.MovieID
            WHERE m.MovieID = ?
            GROUP BY 
                m.MovieID, m.Title, m.Classification, m.DurationMin,
                m.Rating, m.Status, m.ReleaseDate, m.Language;
        """

        columns, rows = DatabaseConnection.execute_query(query, (movie_id,))

        if not rows:
            return None

        return dict(zip(columns, rows[0]))
    
