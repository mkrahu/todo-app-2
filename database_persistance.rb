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
    sql = 'SELECT * FROM lists'
    result = query(sql)

    result.map do |tuple|
      list_id = tuple['id']
      todos = find_list_todos(list_id)

      { id: list_id, name: tuple['name'], todos: todos }
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

  def find_list(id)
    sql = 'SELECT * FROM lists WHERE id = $1'
    result = query(sql, id)

    tuple = result.first
    list_id = tuple['id']
    todos = find_list_todos(list_id)

    { id: list_id, name: tuple['name'], todos: todos }
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

  private

  def find_list_todos(list_id)
    sql = 'SELECT * FROM todos WHERE list_id = $1'
    result = query(sql, list_id)

    result.map do |tuple|
      { id: tuple['id'].to_i,
        name: tuple['name'],
        completed: tuple['complete'] == 't' }
    end
  end
end
