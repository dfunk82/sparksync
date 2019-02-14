class StudentsController < ApplicationController
  # filter which of these methods can be used
  # only allow logged in admin to create or update a student
  before_action :logged_in_user, only: [:index, :create, :update, :show]
  before_action :admin_user, only: [:create, :update]
  before_action :correct_user, only: [:show ]

  # one student
  def show
    store_location
    @dateview = current_dateview

    # title and what column depend on user and in the case
    # of admin, what view she wants
    # nobody but admin and a particular partner has any business
    # doing a school/show
    # can you do the sorting after the db fetch? it would
    # be preferable in order to sort on multiple columns

    @showstudent = false
    @showschool = true
    @showteacher = true
    @showhours = true

    @lessons = Lesson.find_by_student(@student_id, @dateview.start_date, @dateview.end_date)
    if session[:sortcol]
      sortcol = session[:sortcol]
      # case by case as sorting by student' slast name or school name is not
      # straightforward
      if sortcol == "School"
        @lessons = @lessons.sort_by(&:name)
      elsif sortcol == "Date"
        @lessons = @lessons.sort_by(&:time_in).reverse! 
      elsif sortcol == "Teacher"
        @lessons = @lessons.sort_by(&:teacher_last)
      elsif sortcol == "Progress"
        @lessons = @lessons.sort_by(&:progress)
      elsif sortcol == "Behavior"
        @lessons = @lessons.sort_by(&:behavior)
      end
    else
      @lessons = @lessons.sort_by(&:time_in).reverse! 
    end
    @tot_hours = 0
    @lessons.each do |lesson|
      @tot_hours += lesson[:time_out] - lesson[:time_in]
    end
    # convert seconds to hours
    @tot_hours = @tot_hours/3600
  end

  # displays all "right" students and makes it possible to view
  # makes it possible for admin to modify or delete
  def index
    store_location
    @student = Student.new

    prepare_index    
  end

  def prepare_index
    @changev = current_visibility
    @students = find_right_students
    @showbtns = current_user.admin?
    @delete_warning = "Deleting this student will delete all his/her lessons records as well and is irreversible. Are you sure?"
  end

  def handle_error
    prepare_index
    render 'index'
  end

  def find_right_students
    if current_user.admin?
      rightstudents = visible_records(Student)
    elsif current_user.partner?
      rightschool = current_user.school_id
      rightstudents = Student.where(school_id: rightschool)
    else # current_user is a teacher
      sql = "select student_id from lessons where user_id = ?"
      rightids = Lesson.find_by_sql([sql, current_user.id]).map(&:student_id)
      rightstudents = Student.where({id: rightids})
    end
  end
 
  def create
    @student = Student.new(student_params)
    @student.activated = true
    if @student.save
      redirect_to students_url
    else
      handle_error
    end
  end

  def update
    # puts "in update params " + params.to_s
    student_id = params[:id]
    @student = Student.find(student_id)
    if params[:modify]
      puts "modify"
      if Student.update(@student.id,
                        school_id: student_params[:school_id],
                        first_name: student_params[:first_name],
                        last_name: student_params[:last_name],
                        activated: true)
        redirect_to students_url
      else
        handle_error
      end
    elsif params[:delete]
      puts "delete"
      student_id = @student.id 
      who = Student.find(student_id)
      if who.activated
        # don't actually delete, set unactivated
        if who.update( activated: false)
          redirect_to students_url
        else
          handle_error
        end
      else
        if who.delete
          redirect_to students_url
        else
          handle_error
        end
      end
    elsif params[:hours] #TODO remove?
      puts "about to redirect_to student_path " + student_id
      redirect_to student_path(student_id)
    else
      raise Exception.new('not welcome, modify or delete. who called student update?')
    end
  end

  private
    def student_params
      params.require(:student).permit(:first_name, :last_name, :email, :school_id)
    end
    def correct_user
      @student_id = params[:id]
      @student = Student.find(@student_id)
      return if current_user.admin?
      # puts "student " + @student_id.to_s + " school " + @student.school_id.to_s
      # puts "user " + current_user.id.to_s + " school " + current_user.school_id.to_s
      return if current_user.partner? && 
          current_user.school_id == @student.school_id
      evertaught = 
        Lesson.where(user_id: current_user.id).find_by(student_id: @student_id)   
      return if current_user.teacher? && evertaught
      redirect_to students_url
    end
end
