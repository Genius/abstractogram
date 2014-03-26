module ApplicationHelper
  def mobile_device?
    request.user_agent =~ /Mobile|webOS/
  end
  
  def submit_text
    mobile_device? ? "Search" : "Search RailsConf Abstracts!"
  end
  
  def name_of_site
    "Abstractogram"
  end
  
  def github_url
    "https://github.com/RapGenius/abstractogram"
  end
end
