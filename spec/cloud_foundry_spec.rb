require 'spec_helper'

module CloudfoundryBlueGreenDeploy
  describe CloudFoundry do
    describe '#push' do
      subject { CloudFoundry.push(app) }
      let(:app) { 'app_name-blue' }

      it 'invokes the CloudFoundry CLI command "push"' do
        expect(CommandLine).to receive(:system).with("cf push #{app}").and_return(true)
        subject
      end

      context 'when the CloudFoundry push fails' do
        before do
          allow(CommandLine).to receive(:system).and_return(false)
        end
        it 'throws a CloudFoundryCliError' do
          expect{ subject }.to raise_error(CloudFoundryCliError)
        end
      end
    end

    describe '#stop' do
      subject { CloudFoundry.stop(app) }
      let(:app) { 'app_name-blue' }

      it 'invokes the CloudFoundry CLI command "stop"' do
        expect(CommandLine).to receive(:system).with("cf stop #{app}").and_return(true)
        subject
      end

      context 'when the CloudFoundry push fails' do
        before do
          allow(CommandLine).to receive(:system).and_return(false)
        end
        it 'throws a CloudFoundryCliError' do
          expect{ subject }.to raise_error(CloudFoundryCliError)
        end
      end
    end

    describe '#apps' do
      subject { CloudFoundry.apps }
      before do
        allow(CommandLine).to receive(:backtick).with('cf apps').and_return(cli_apps_output)
      end

      context 'there is a list of apps defined in the current organization' do
        let(:cli_apps_output) {
          <<-CLI
        Getting apps in org LA-Ping-Pong-Ding-Dongs / space carrot-soup as pivot-pong-developers@googlegroups.com...
        OK

        name                requested state   instances   memory   disk   urls
        carrot-soup-blue    stopped           0/1         1G       1G     carrot-soup-blue.cfapps.io
        carrot-soup-green   started           1/1         1G       1G     la-pong.cfapps.io, carrot-soup-green.cfapps.io
        red                 started           1/1         1G       1G     relish.cfapps.io
          CLI
        }

        it 'parses the CLI "apps" output into a collection of App objects, one for each app' do
          expect(subject).to be_kind_of(Array)
          expect(subject.length).to eq 3
          expect(subject[0].name).to eq 'carrot-soup-blue'
          expect(subject[0].state).to eq 'stopped'
          expect(subject[1].name).to eq 'carrot-soup-green'
          expect(subject[1].state).to eq 'started'
        end
      end

    end

    describe '#routes' do
      subject { CloudFoundry.routes }
      before do
        allow(CommandLine).to receive(:backtick).with('cf routes').and_return(cli_routes_output)
      end

      context 'there is a route defined in the current organization' do
        let(:cli_routes_output) {
          <<-CLI
        Getting routes as pivot-pong-developers@googlegroups.com ...

        host                 domain      apps
        pivot-pong-blue      cfapps.io   pivot-pong-staging-blue
        pivot-pong-green     cfapps.io   pivot-pong-staging-green
        la-pong              cfapps.io   pivot-pong-staging-green
          CLI
        }


        it 'parses the CLI "routes" output into a collection of Route objects, one for each route' do
          expect(subject).to be_kind_of(Array)
          expect(subject.length).to eq 3
          expect(subject[0].host).to eq 'pivot-pong-blue'
          expect(subject[0].domain).to eq 'cfapps.io'
          expect(subject[0].app).to eq 'pivot-pong-staging-blue'
        end
      end

      context '"cf routes" fails with an error' do
        let(:cli_routes_output) {
          <<-CLI
        Getting routes as pivot-pong-developers@googlegroups.com ...

        FAILED
        Failed fetching routes.
          CLI
        }
        it 'throws a CloudFoundryCliError' do
          expect{ subject }.to raise_error(CloudFoundryCliError)
        end
      end
    end

    describe '#map_route' do
      let(:app) { 'the-app' }
      let(:domain) { 'the-domain' }
      let(:host) { 'the-host' }

      subject { CloudFoundry.map_route(app, domain, host) }

      it 'invokes the CloudFoundry CLI command "map-route" with the proper set of parameters' do
        expect(CommandLine).to receive(:system).with("cf map-route #{app} #{domain} -n #{host}").and_return(true)
        subject
      end

      context 'when the CloudFoundry map-route fails' do
        before do
          allow(CommandLine).to receive(:system).and_return(false)
        end
        it 'throws a CloudFoundryCliError' do
          expect{ subject }.to raise_error(CloudFoundryCliError)
        end
      end
    end

    describe '#unmap_route' do
      let(:app) { 'the-app' }
      let(:domain) { 'the-domain' }
      let(:host) { 'the-host' }

      subject { CloudFoundry.unmap_route(app, domain, host) }

      it 'invokes the CloudFoundry CLI command "unmap-route" with the proper set of parameters' do
        expect(CommandLine).to receive(:system).with("cf unmap-route #{app} #{domain} -n #{host}").and_return(true)
        subject
      end

      context 'when the CloudFoundry unmap-route fails' do
        before do
          allow(CommandLine).to receive(:system).and_return(false)
        end
        it 'throws a CloudFoundryCliError' do
          expect{ subject }.to raise_error(CloudFoundryCliError)
        end
      end
    end
  end
end
