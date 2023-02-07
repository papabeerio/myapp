from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_mysqldb import MySQL
import MySQLdb.cursors
from os import getenv

my_dbhost = getenv('MYSQL_HOST', default='localhost')
my_dbuser = getenv('MYSQL_USER', default='root')
my_dbpass = getenv('MYSQL_PASS', default='root')

app = Flask(__name__)

app.app_context().push()

#/// = relative path, //// = absolute path
#app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///db.sqlite'
app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql://root:root@{my_dbhost}/flask'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

app.config['MYSQL_HOST'] = my_dbhost
app.config['MYSQL_USER'] = my_dbuser
app.config['MYSQL_PASSWORD'] = my_dbpass
app.config['MYSQL_DB'] = 'flask'

my = MySQL(app)

# Create table
cursor = my.connection.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS todo(id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, complete boolean not null default 0)")
my.connection.commit()
cursor.close()

class Todo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100))
    complete = db.Column(db.Boolean)

db.create_all()


@app.get("/")
def home():
    # todo_list = Todo.query.all()
#    cursor = mysql.connection.cursor()
#    todo_list = db.session.query(Todo).all()
    todo_list = db.session.query(Todo).all()
    #return f"Hello, World! {todo_list}"
    return render_template("base.html", todo_list=todo_list)


# @app.route("/add", methods=["POST"])
@app.post("/add")
def add():
    title = request.form.get("title")
    new_todo = Todo(title=title, complete=False)
    db.session.add(new_todo)
    db.session.commit()
    return redirect(url_for("home"))


@app.get("/update/<int:todo_id>")
def update(todo_id):
    # todo = Todo.query.filter_by(id=todo_id).first()
    todo = db.session.query(Todo).filter(Todo.id == todo_id).first()
    todo.complete = not todo.complete
    db.session.commit()
    return redirect(url_for("home"))


@app.get("/delete/<int:todo_id>")
def delete(todo_id):
    # todo = Todo.query.filter_by(id=todo_id).first()
    todo = db.session.query(Todo).filter(Todo.id == todo_id).first()
    db.session.delete(todo)
    db.session.commit()
    return redirect(url_for("home"))
