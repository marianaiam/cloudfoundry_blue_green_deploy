require 'spec_helper'

describe Route do
  describe '.initialize' do
    context 'when supplied an empty "app"' do
      it 'reports "app" as nil' do
        expect(Route.new('blah', 'blah', '').app).to be_nil
      end
    end
  end
end

