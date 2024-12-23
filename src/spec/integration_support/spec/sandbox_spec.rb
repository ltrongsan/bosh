require 'spec_helper'
require 'integration_support/sandbox'
require 'integration_support/uaa_service'

module IntegrationSupport
  describe Sandbox do
    let(:uaa){ double(UaaService)}
    before do
      allow(UaaService).to receive(:new).and_return(uaa)
      allow(uaa).to receive(:port).and_return(9999)
      allow(uaa).to receive(:reconfigure)
    end

    subject(:sandbox) { Sandbox.new({ type: 'sqlite'}, nil, 0) }

    describe '#run' do
      before do
        allow(sandbox).to receive(:start)
        allow(sandbox).to receive(:stop)
        allow(sandbox).to receive(:loop)
      end

      it 'starts the sandbox' do
        sandbox.run
        expect(sandbox).to have_received(:start)
      end

      it 'waits for an interrupt from the user to stop' do
        allow(sandbox).to receive(:loop).and_raise(Interrupt)
        sandbox.run
        expect(sandbox).to have_received(:loop)
        expect(sandbox).to have_received(:stop)
      end

      it 'always stops the standbox' do
        allow(sandbox).to receive(:loop).and_raise('Something unexpected and bad happened')
        expect { sandbox.run }.to raise_error(/unexpected/)
        expect(sandbox).to have_received(:stop)
      end

      it 'exposes needed ENV vars for running ruby' do
        allow(ENV).to receive(:[]).with('PATH').and_return('dummy-path')
        allow(ENV).to receive(:[]).with('GEM_HOME').and_return('dummy-gem-home')
        allow(ENV).to receive(:[]).with('GEM_PATH').and_return('dummy-gem-path')

        external_cpi_config = sandbox.director_config.external_cpi_config
        expect(external_cpi_config[:env_path]).to eq('dummy-path')
        expect(external_cpi_config[:gem_home]).to eq('dummy-gem-home')
        expect(external_cpi_config[:gem_path]).to eq('dummy-gem-path')
      end
    end
  end
end
