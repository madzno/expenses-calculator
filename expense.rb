#! /usr/bin/env ruby

require "pg"

require "io/console"

class ExpenseData
  def initialize
    @connection = PG.connect(dbname: "expenses")
  end

  def list_expenses
    result = @connection.exec "SELECT * FROM expenses ORDER BY created_on;"
    display_count(result)
    display_expenses(result) if result.ntuples > 0
  end

  def add_expense(amount, memo)
    sql = "INSERT INTO expenses (amount, memo) VALUES ($1, $2)"
    @connection.exec_params(sql, [amount, memo])
  end

  def search_expenses(term)
    sql = "SELECT * FROM expenses WHERE memo ILIKE $1"
    result = @connection.exec_params(sql, ["%#{term}%"])
    display_count(result)
    display_expenses(result) if result.ntuples > 0
  end

  def delete_expense(id)
    sql = "SELECT * FROM expenses WHERE id = $1"
    result = @connection.exec_params(sql, [id])

    if result.ntuples == 1
      sql = "DELETE FROM expenses WHERE id = $1"
      @connection.exec_params(sql, [id])
      puts "The following expense has been deleted:"
      display_expenses(result)
    else
      puts "There is no expense with the id '#{id}'."
    end
  end

  def delete_all_expenses
    @connection.exec("DELETE FROM expenses")
    puts "All expenses have been deleted."
  end

  private

  def display_count(expenses)
    count = expenses.ntuples
    if count == 0
      puts "There are no expenses."
    elsif count == 1
      puts "There is 1 expense."
    else
      puts "There are #{count} expenses."
    end
  end

  def display_expenses(result)
    result.each do |tuple|
      columns = [ tuple["id"].rjust(3),
                  tuple["created_on"].rjust(10),
                  tuple["amount"].rjust(12),
                  tuple["memo"] ]
      puts columns.join(" | ")
    end

    puts "-" * 50

    amount_sum = result.field_values("amount").map(&:to_f).sum

    puts "Total #{format('%.2f', amount_sum.to_s.rjust(25))}"
  end
end

class CLI
  def initialize
    @application = ExpenseData.new
  end

  def display_help
    help_content = <<~RUBY
      An expense recording system

      Commands:

      add AMOUNT MEMO - record a new expense
      clear - delete all expenses
      list - list all expenses
      delete NUMBER - remove expense with id NUMBER
      search QUERY - list expenses with a matching memo field
    RUBY
    puts help_content
  end

  def run(arguments)
    command = arguments.shift
    case command
    when "add"
      amount = arguments[0]
      memo = arguments[1]
      abort "You must provide an amount and memo." unless amount && memo
      @application.add_expense(amount, memo)
    when "list"
      @application.list_expenses
    when "search"
      @application.search_expenses(arguments[0])
    when "delete"
      @application.delete_expense(arguments[0])
    when "clear"
      puts "This will remove all expenses. Are you sure? (y/n)"
      response = $stdin.getch
      @application.delete_all_expenses if response == "y"
    else
      display_help
    end
  end
end

CLI.new.run(ARGV)
