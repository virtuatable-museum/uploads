module Services
  class Characters < Services::Uploaders::Base
    def initialize
      super
      @directory = 'characters'
    end
  end
end