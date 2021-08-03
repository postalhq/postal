class ApplicationRecord < ActiveRecord::Base

  self.abstract_class = true
  self.inheritance_column = "sti_type"
  nilify_blanks

end
