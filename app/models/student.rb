class Student < ApplicationRecord
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :last_name, uniqueness: {scope: [:first_name, :school_id] }

  belongs_to :school
  has_many :lessons
  default_scope -> { order(last_name: :asc) }

  def self.find_by_school(school_id)
    self.where(school_id: school_id, activated: true)
  end

  def self.find_by_teacher(teacher_id)
    sql = "select student_id from lessons where user_id = ?"
    rightids = Lesson.find_by_sql([sql, teacher_id]).map(&:student_id)
    rightids &= self.where(activated: true).ids
    self.where({id: rightids})    
  end
end
