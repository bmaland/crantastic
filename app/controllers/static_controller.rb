# Simple controller for (semi) static pages. Each page requires a new entry
# in =routes.rb=. If we end up with many of these pages we should look into a
# more sophisticated solution.

class StaticController < ApplicationController

  def about
    @title = "About"
  end

  def error_404
  end

  def error_500
  end

end
