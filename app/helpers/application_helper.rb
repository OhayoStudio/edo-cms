module ApplicationHelper
	def articles_section?
		controller_name == 'articles'
	end
end
