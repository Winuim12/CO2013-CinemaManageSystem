from .database import DatabaseConnection

class ReportModel:
    @staticmethod
    def get_monthly_revenue_all(cinema_id, month, year, min_revenue=0.0):
        query = """
            EXEC sp_GetMonthlyCinemaRevenue
                @CinemaID = ?,
                @Year = ?,
                @Month = ?,
                @MinRevenue = ?
        """
        params = (cinema_id, year, month, min_revenue)
        columns, rows = DatabaseConnection.execute_query(query, params)
        result = []
        for row in rows:
            result.append({ columns[i]: row[i] for i in range(len(columns)) })
        return result