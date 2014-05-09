module CloudfoundryBlueGreenDeploy
  class CommandLine
    DEBUG = false
    def self.backtick(command)

      output = `export CF_COLOR=false; #{command}`
      puts "CommandLine.backtick(): \"#{output}\"" if DEBUG
      output
    end

    def self.system(command)
      Kernel.system(command)
    end
  end
end
