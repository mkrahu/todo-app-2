require 'pg'

class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement} : #{params}"
    @db.exec_params(statement, params)
  end

  def lists
    sql = <<~SQL
      SELECT
        l.id,
        l.name,
        COUNT(t.id) as todos_count,
        COUNT(NULLIF(t.complete, true)) AS todos_remaining_count
      FROM lists l
        LEFT OUTER JOIN todos t ON l.id = t.list_id
      GROUP BY l.id;
    SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list(tuple)
    end
  end

  def create_list(list_name)
    sql = 'INSERT INTO lists (name) VALUES ($1);'
    query(sql, list_name)
  end

  def delete_list(id)
    sql = 'DELETE FROM lists WHERE id = $1'
    query(sql, id)
  end

  def find_list(list_id)
    sql =  sql = <<~SQL
      SELECT
        l.id,
        l.name,
        COUNT(t.id) as todos_count,
        COUNT(NULLIF(t.complete, true)) AS todos_remaining_count
      FROM lists l
        LEFT OUTER JOIN todos t ON l.id = t.list_id
      WHERE l.id = $1
      GROUP BY l.id;
    SQL
    result = query(sql, list_id)

    tuple = result.first

    tuple_to_list(tuple)
  end

  def update_list_name(id, name)
    sql = 'UPDATE lists SET name = $1 WHERE id = $2'
    query(sql, name, id)
  end

  def create_todo(list_id, todo_name)
    sql = 'INSERT INTO todos (list_id, name) VALUES ($1, $2);'
    query(sql, list_id, todo_name)
  end

  def delete_todo(list_id, todo_id)
    sql = 'DELETE FROM todos WHERE list_id = $1 AND id = $2'
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, status)
    sql = 'UPDATE todos SET complete = $3 WHERE list_id = $1 AND id = $2'
    query(sql, list_id, todo_id, status)
  end

  def mark_all_todos_completed(list_id)
    sql = 'UPDATE todos SET complete = true WHERE list_id = $1'
    query(sql, list_id)
  end

  def find_list_todos(list_id)
    sql = 'SELECT * FROM todos WHERE list_id = $1'
    result = query(sql, list_id)

    result.map do |tuple|
      { id: tuple['id'].to_i,
        name: tuple['name'],
        completed: tuple['complete'] == 't' }
    end
  end

  private

  def tuple_to_list(tuple)
    { id: tuple['id'],
      name: tuple['name'],
      todos_count: tuple['todos_count'].to_i,
      todos_remaining_count: tuple['todos_remaining_count'].to_i }
  end
end
