require 'spec_helper'

module CloudfoundryBlueGreenDeploy
  describe CommandLine do
    describe 'backtick' do
      it 'runs the supplied command and returns the stdout string' do
        expect(CommandLine.backtick('echo "sports"')).to eq "sports\n"
      end
      it 'ensures that cf output omits ANSI color sequences' do
        expect(CommandLine.backtick('echo $CF_COLOR')).to eq "false\n"
      end
    end

    describe 'system' do
      it 'runs the supplied command using Kernel.system' do
        expect(Kernel).to receive(:system)
        CommandLine.system('echo "sports"')
      end
    end
  end
end
