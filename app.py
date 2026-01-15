import os
from flask import Flask
import secrets
from controllers.auth_controller import auth_bp
from controllers.manager_controller import manager_bp
from controllers.customer_controller import customer_bp
from config import DB_CONFIG


def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=False)

    # secret key
    app.secret_key = os.environ.get('SECRET_KEY') or secrets.token_hex(32)

    # load config
    app.config['DB_CONFIG'] = DB_CONFIG

    # register blueprints
    app.register_blueprint(auth_bp)
    app.register_blueprint(manager_bp, url_prefix='/manager')
    app.register_blueprint(customer_bp, url_prefix='/customer')

    @app.context_processor
    def inject_logout_route():
        if 'auth' in app.blueprints:
            return {'logout_endpoint': 'auth.logout'}
        return {'logout_endpoint': 'logout'}
    return app


if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, host='0.0.0.0', port=5000)
