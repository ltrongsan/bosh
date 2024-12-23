require 'securerandom'
require 'spec_helper'

describe 'create-release', type: :integration do
  include IntegrationSupport::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  let(:sha2_regexp) { /^[0-9a-f]{64}$/ }
  let(:sha2_prefixed_regexp) { /^sha256:[0-9a-f]{64}$/ }

  before do
    setup_test_release_dir
  end

  let(:sha_generator) do
    path = IntegrationSupport::VerifyMultidigestManager.executable_path
    Bosh::Director::BoshDigest::MultiDigest.new(logger, path)
  end
  let!(:release_file) { Tempfile.new('release.tgz') }
  after { release_file.delete }

  describe 'release creation' do
    before do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        bosh_runner.run_in_current_dir("create-release --final --tarball=#{release_file.path}")
      end
    end

    it 'stashes release artifacts in a tarball' do
      actual = list_tar_files(release_file.path)
      expected = [
        'LICENSE',
        'jobs/bazquux.tgz',
        'jobs/emoji-errand.tgz',
        'jobs/errand1.tgz',
        'jobs/errand_without_package.tgz',
        'jobs/fails_with_too_much_output.tgz',
        'jobs/foobar.tgz',
        'jobs/foobar_with_bad_properties.tgz',
        'jobs/foobar_with_bad_properties_2.tgz',
        'jobs/job_with_many_packages.tgz',
        'jobs/foobar_without_packages.tgz',
        'jobs/has_drain_script.tgz',
        'jobs/job_with_blocking_compilation.tgz',
        'jobs/job_1_with_pre_start_script.tgz',
        'jobs/job_1_with_post_deploy_script.tgz',
        'jobs/job_2_with_pre_start_script.tgz',
        'jobs/job_2_with_post_deploy_script.tgz',
        'jobs/job_1_with_many_properties.tgz',
        'jobs/job_2_with_many_properties.tgz',
        'jobs/job_3_with_many_properties.tgz',
        'jobs/job_with_property_types.tgz',
        'jobs/job_with_post_start_script.tgz',
        'jobs/job_3_with_broken_post_deploy_script.tgz',
        'jobs/job_that_modifies_properties.tgz',
        'jobs/transitive_deps.tgz',
        'jobs/id_job.tgz',
        'jobs/job_with_bad_template.tgz',
        'jobs/local_dns_records_json.tgz',
        'packages/a.tgz',
        'packages/b.tgz',
        'packages/bar.tgz',
        'packages/blocking_package.tgz',
        'packages/c.tgz',
        'packages/errand1.tgz',
        'packages/fails_with_too_much_output.tgz',
        'packages/foo.tgz',
        'packages/foo_1.tgz',
        'packages/foo_2.tgz',
        'packages/foo_3.tgz',
        'packages/foo_4.tgz',
        'packages/foo_5.tgz',
        'packages/foo_6.tgz',
        'packages/foo_7.tgz',
        'packages/foo_8.tgz',
        'packages/foo_9.tgz',
        'packages/foo_10.tgz',
        'release.MF',
        'license.tgz',
      ]

      expect(actual).to contain_exactly(*expected)
    end

    it 'updates the .final_builds index for each job, package and license' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        package_files = {
          'a' => ['./packaging', './a/run.sh'],
          'b' => ['./packaging', './b/run.sh'],
          'bar' => ['./packaging', './bar/run.sh'],
          'blocking_package' => ['./packaging', './foo'],
          'c' => ['./packaging', './c/run.sh'],
          'errand1' => ['./packaging', './errand1/file.sh'],
          'fails_with_too_much_output' => ['./packaging', './foo'],
          'foo' => ['./packaging', './foo'],
        }

        package_files.each do |package_name, files|
          it_creates_artifact("packages/#{package_name}", files)
        end

        job_files = {
          'errand1' => ['./templates/ctl', './templates/run', './monit', './job.MF'],
          'errand_without_package' => ['./templates/run', './monit', './job.MF'],
          'fails_with_too_much_output' => ['./monit', './job.MF'],
          'foobar' => ['./templates/drain.erb', './templates/foobar_ctl', './monit', './job.MF'],
          'foobar_with_bad_properties' => ['./templates/drain.erb', './templates/foobar_ctl', './monit', './job.MF'],
          'foobar_with_bad_properties_2' => ['./templates/drain.erb', './templates/foobar_ctl', './monit', './job.MF'],
          'foobar_without_packages' => ['./templates/foobar_ctl', './monit', './job.MF'],
          'job_with_blocking_compilation' => ['./monit', './job.MF'],
          'transitive_deps' => ['./monit', './job.MF'],
          'id_job' => ['./monit', './templates/config.yml.erb', './job.MF'],
          'job_1_with_post_deploy_script' => ['./monit', './job.MF', './templates/post-deploy.erb', './templates/job_1_ctl'],
          'job_2_with_post_deploy_script' => ['./monit', './job.MF', './templates/post-deploy.erb', './templates/job_2_ctl'],
          'job_3_with_broken_post_deploy_script' => [
            './monit',
            './job.MF',
            './templates/broken-post-deploy.erb',
            './templates/job_3_ctl',
          ],
          'local_dns_records_json' => ['./monit', './job.MF', './templates/pre-start.erb'],
        }

        job_files.each do |job_name, files|
          it_creates_artifact("jobs/#{job_name}", files)
        end

        it_creates_artifact('license', ['./LICENSE'])
      end
    end

    it 'creates a release manifest' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        release_manifest = YAML.load_file(latest_release_manifest)
        expect(release_manifest['commit_hash']).to match(/[0-9a-f]{7}/)
        expect(release_manifest['license']).to match(license_desc)
        expect(release_manifest['name']).to eq('bosh-release')
        expect(release_manifest['version']).to eq('1')

        expect(release_manifest['packages']).to contain_exactly(
                                                        package_desc('a', ['b']),
                                                        package_desc('b', ['c']),
                                                        package_desc('bar', ['foo']),
                                                        package_desc('blocking_package', []),
                                                        package_desc('c', []),
                                                        package_desc('errand1', []),
                                                        package_desc('fails_with_too_much_output', []),
                                                        package_desc('foo', []),
                                                        package_desc('foo_1', []),
                                                        package_desc('foo_2', []),
                                                        package_desc('foo_3', []),
                                                        package_desc('foo_4', []),
                                                        package_desc('foo_5', []),
                                                        package_desc('foo_6', []),
                                                        package_desc('foo_7', []),
                                                        package_desc('foo_8', []),
                                                        package_desc('foo_9', []),
                                                        package_desc('foo_10', []),
                                                      )

        expect(release_manifest['jobs']).to contain_exactly(
                                                    job_desc('emoji-errand'),
                                                    job_desc('errand1', ['errand1']),
                                                    job_desc('errand_without_package'),
                                                    job_desc('fails_with_too_much_output', ['fails_with_too_much_output']),
                                                    job_desc('foobar', %w[foo bar]),
                                                    job_desc('bazquux'),
                                                    job_desc('foobar_with_bad_properties', %w[foo bar]),
                                                    job_desc('foobar_with_bad_properties_2', %w[foo bar]),
                                                    job_desc('foobar_without_packages'),
                                                    job_desc('job_with_many_packages',
                                                             %w[
                                                               foo_1
                                                               foo_2
                                                               foo_3
                                                               foo_4
                                                               foo_5
                                                               foo_6
                                                               foo_7
                                                               foo_8
                                                               foo_9
                                                               foo_10
                                                             ]),
                                                    job_desc('has_drain_script', %w[foo bar]),
                                                    job_desc('job_with_blocking_compilation', ['blocking_package']),
                                                    job_desc('job_1_with_pre_start_script'),
                                                    job_desc('job_2_with_pre_start_script'),
                                                    job_desc('job_1_with_post_deploy_script'),
                                                    job_desc('job_2_with_post_deploy_script'),
                                                    job_desc('job_3_with_broken_post_deploy_script'),
                                                    job_desc('job_that_modifies_properties', %w[foo bar]),
                                                    job_desc('job_1_with_many_properties'),
                                                    job_desc('job_2_with_many_properties'),
                                                    job_desc('job_3_with_many_properties'),
                                                    job_desc('job_with_property_types'),
                                                    job_desc('job_with_post_start_script'),
                                                    job_desc('transitive_deps', ['a']),
                                                    job_desc('id_job'),
                                                    job_desc('job_with_bad_template'),
                                                    job_desc('local_dns_records_json'),
                                                  )

        expect(release_manifest['uncommitted_changes']).to eq(false)
      end
    end

    it 'updates the index' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        index = YAML.load_file('releases/bosh-release/index.yml')
        builds = index['builds']
        uuid, = builds.first
        expect(index).to eq(
          'builds' => {
            uuid => { 'version' => '1' },
          },
          'format-version' => '2',
        )
      end
    end
  end

  describe 'release creation from manifest' do
    before do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        bosh_runner.run_in_current_dir('create-release --final')

        bosh_runner.run_in_current_dir("create-release #{latest_release_manifest} --tarball=#{release_file.path}")
      end
    end

    it 'stashes release artifacts in a tarball' do
      actual = list_tar_files(release_file.path)
      expected = [
        'LICENSE',
        'jobs/emoji-errand.tgz',
        'jobs/errand1.tgz',
        'jobs/errand_without_package.tgz',
        'jobs/fails_with_too_much_output.tgz',
        'jobs/foobar.tgz',
        'jobs/bazquux.tgz',
        'jobs/foobar_with_bad_properties.tgz',
        'jobs/foobar_with_bad_properties_2.tgz',
        'jobs/job_with_many_packages.tgz',
        'jobs/foobar_without_packages.tgz',
        'jobs/has_drain_script.tgz',
        'jobs/job_with_blocking_compilation.tgz',
        'jobs/job_1_with_pre_start_script.tgz',
        'jobs/job_1_with_post_deploy_script.tgz',
        'jobs/job_2_with_pre_start_script.tgz',
        'jobs/job_2_with_post_deploy_script.tgz',
        'jobs/job_1_with_many_properties.tgz',
        'jobs/job_2_with_many_properties.tgz',
        'jobs/job_3_with_many_properties.tgz',
        'jobs/job_with_property_types.tgz',
        'jobs/job_with_post_start_script.tgz',
        'jobs/job_3_with_broken_post_deploy_script.tgz',
        'jobs/job_that_modifies_properties.tgz',
        'jobs/transitive_deps.tgz',
        'jobs/id_job.tgz',
        'jobs/job_with_bad_template.tgz',
        'jobs/local_dns_records_json.tgz',
        'packages/a.tgz',
        'packages/b.tgz',
        'packages/bar.tgz',
        'packages/blocking_package.tgz',
        'packages/c.tgz',
        'packages/errand1.tgz',
        'packages/fails_with_too_much_output.tgz',
        'packages/foo.tgz',
        'packages/foo_1.tgz',
        'packages/foo_2.tgz',
        'packages/foo_3.tgz',
        'packages/foo_4.tgz',
        'packages/foo_5.tgz',
        'packages/foo_6.tgz',
        'packages/foo_7.tgz',
        'packages/foo_8.tgz',
        'packages/foo_9.tgz',
        'packages/foo_10.tgz',
        'release.MF',
        'license.tgz',
      ]

      expect(actual).to contain_exactly(*expected)
    end
  end

  it 'allows creation of new final releases with the same content as the latest final release' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create-release --final')
      expect(parse_release_version(out)).to eq('1')

      out = bosh_runner.run_in_current_dir('create-release --final --force')
      expect(parse_release_version(out)).to eq('2')

      out = bosh_runner.run_in_current_dir('create-release --final --force')
      expect(parse_release_version(out)).to eq('3')
    end
  end

  it 'allows creation of new dev releases with the same content as the latest dev release' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create-release')
      expect(parse_release_version(out)).to eq('0+dev.1')

      out = bosh_runner.run_in_current_dir('create-release --force')
      expect(parse_release_version(out)).to eq('0+dev.2')

      out = bosh_runner.run_in_current_dir('create-release --force')
      expect(parse_release_version(out)).to eq('0+dev.3')
    end
  end

  it 'allows creation of new final releases with the same content as a previous final release' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create-release --final')
      expect(parse_release_version(out)).to eq('1')

      with_changed_release do
        out = bosh_runner.run_in_current_dir('create-release --final --force')
        expect(parse_release_version(out)).to eq('2')
      end

      out = bosh_runner.run_in_current_dir('create-release --final --force')
      expect(parse_release_version(out)).to eq('3')
    end
  end

  it 'allows creation of new dev releases with the same content as a previous dev release' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create-release')
      expect(parse_release_version(out)).to eq('0+dev.1')

      with_changed_release do
        out = bosh_runner.run_in_current_dir('create-release --force')
        expect(parse_release_version(out)).to eq('0+dev.2')
      end

      out = bosh_runner.run_in_current_dir('create-release --force')
      expect(parse_release_version(out)).to eq('0+dev.3')
    end
  end

  it 'allows creation of new final release without .gitignore files' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      out = bosh_runner.run_in_current_dir('create-release --final')
      expect(out).to match(/Version\s*1/)

      `git add .`
      `git commit -m 'final release 1'`
      `git clean -fdx`

      out = bosh_runner.run_in_current_dir('create-release --final --force')
      expect(out).to match(/Version\s*2/)
    end
  end

  context 'when no previous releases have been made' do
    it 'final release uploads the job & package blobs' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        expect(File).to_not exist('releases/bosh-release/bosh-release-0.yml')

        out = bosh_runner.run_in_current_dir('create-release --final')
        expect(out).to match(/Finished uploading/)
      end
    end

    it 'uses a provided --name' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create-release --name "bosh-fork"')
        expect(parse_release_name(out)).to eq('bosh-fork')
        expect(parse_release_version(out)).to eq('0+dev.1')
      end
    end
  end

  context 'when previous release have been made' do
    it 'allows creation of a new dev release with a new name' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create-release')
        expect(parse_release_name(out)).to eq('bosh-release')
        expect(parse_release_version(out)).to eq('0+dev.1')

        out = bosh_runner.run_in_current_dir('create-release --name "bosh-fork"')
        expect(parse_release_name(out)).to eq('bosh-fork')
        expect(parse_release_version(out)).to eq('0+dev.1')
      end
    end

    it 'allows creation of a new final release with a new name' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create-release --final')
        expect(parse_release_name(out)).to eq('bosh-release')
        expect(parse_release_version(out)).to eq('1')

        `git add config/final.yml`
        `git add .final_builds`
        `git add releases`
        `git commit -m 'final release 1'`

        out = bosh_runner.run_in_current_dir('create-release --final --name "bosh-fork"')
        expect(parse_release_name(out)).to eq('bosh-fork')
        expect(parse_release_version(out)).to eq('1')
      end
    end

    it 'allows creation of a new final release with a custom name & version' do
      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        out = bosh_runner.run_in_current_dir('create-release --final --name fake-release --version 2.0.1')
        expect(parse_release_name(out)).to eq('fake-release')
        expect(parse_release_version(out)).to eq('2.0.1')
      end
    end
  end

  it 'creates a new final release with a default version' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      File.open('config/final.yml', 'w') do |final|
        final.puts YAML.dump(
          'final_name' => 'bosh-release',
          'blobstore' => {
            'provider' => 'local',
            'options' => { 'blobstore_path' => current_sandbox.blobstore_storage_dir },
          },
        )
      end
      File.open('config/private.yml', 'w') do |final|
        final.puts YAML.dump(
          'blobstore_secret' => 'something',
          'blobstore' => {
            'local' => {},
          },
        )
      end

      bosh_runner.run_in_current_dir('create-release --force')

      out = bosh_runner.run_in_current_dir('create-release --final --force')
      expect(parse_release_version(out)).to eq('1')
      manifest1 = File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-1.yml')
      expect(File).to exist(manifest1)

      # modify a release file to force a new version
      `echo ' ' >> #{File.join(IntegrationSupport::ClientSandbox.test_release_dir, 'jobs', 'foobar', 'templates', 'foobar_ctl')}`
      bosh_runner.run_in_current_dir('create-release --force')

      out = bosh_runner.run_in_current_dir('create-release --final --force')
      expect(parse_release_version(out)).to eq('2')
      manifest2 = File.join(Dir.pwd, 'releases', 'bosh-release', 'bosh-release-2.yml')
      expect(File).to exist(manifest2)
    end
  end

  it 'release tarball does not include excluded files' do
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      bosh_runner.run_in_current_dir("create-release --tarball=#{release_file.path}")

      Dir.mktmpdir do |temp_dir|
        `tar xzf #{release_file.path} -C #{temp_dir}`
        foo_package = File.join(temp_dir, 'packages', 'foo.tgz')
        release_file_list = list_tar_files(foo_package)

        release_file_list.each do |file|
          expect(file).to_not match('excluded_file')
        end
        expect(release_file_list).to include('./foo')
      end
    end
  end

  describe 'release cache' do
    let!(:second_test_release_dir) { Dir.mktmpdir('second-test-release-dir') }
    after { FileUtils.rm_rf(second_test_release_dir) }

    it 'creates releases from different folder using the shared cache' do
      setup_test_release_dir(second_test_release_dir)

      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        bosh_runner.run_in_current_dir('create-release')
      end

      Dir.chdir(second_test_release_dir) do
        bosh_runner.run_in_current_dir('create-release')
      end

      Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
        bosh_runner.run_in_current_dir('upload-release')
      end
    end
  end

  def with_changed_release
    new_file = File.join('src', 'bar', SecureRandom.uuid)
    begin
      FileUtils.touch(new_file)
      yield
    ensure
      FileUtils.rm_rf(new_file)
    end
  end

  def package_desc(name, dependencies)
    match(
      'name' => name,
      'version' => sha2_regexp,
      'fingerprint' => sha2_regexp,
      'dependencies' => dependencies,
      'sha1' => sha2_prefixed_regexp,
    )
  end

  def job_desc(name, packages = [])
    match(
      'name' => name,
      'version' => sha2_regexp,
      'fingerprint' => sha2_regexp,
      'sha1' => sha2_prefixed_regexp,
      'packages' => packages,
    )
  end

  def license_desc
    match(
      'version' => sha2_regexp,
      'fingerprint' => sha2_regexp,
      'sha1' => sha2_prefixed_regexp,
    )
  end

  def latest_release_manifest
    Dir['releases/bosh-release/bosh-release-*.yml'].max_by { |x| File.mtime(x) }
  end

  def it_creates_artifact(artifact_path, expected_files = [])
    index = YAML.load_file(".final_builds/#{artifact_path}/index.yml")
    fingerprint = index['builds'].keys.first
    expect(index).to match(
      'builds' => {
        fingerprint => {
          'version' => fingerprint,
          'sha1' => sha2_prefixed_regexp,
          'blobstore_id' => kind_of(String),
        },
      },
      'format-version' => '2',
    )

    checksum = index['builds'][fingerprint]['sha1']
    artifact_tarball = File.join(ENV['HOME'], '.bosh', 'cache', checksum)
    expect(File.exist?(artifact_tarball)).to eq(true)

    tarblob = File.join(IntegrationSupport::ClientSandbox.blobstore_dir, index['builds'][fingerprint]['blobstore_id'])
    expect(File.exist?(tarblob)).to eq(true)
    actual_digest = sha_generator.create([Bosh::Director::BoshDigest::MultiDigest::SHA256], tarblob)
    expect(actual_digest).to eq(checksum)

    expect(list_tar_files(tarblob)).to match_array(expected_files) unless expected_files.empty?
  end

  def list_tar_files(tarball_path)
    `tar -ztf #{tarball_path}`.chomp.split(/\n/).reject do |f|
      f =~ %r{/$} || # exclude "f" ending in '/' - these are directories
        f =~ %r{.*\._.+} # exclude "f" matching "._" - these are macOS resource forks in a tar archive
    end
  end
end
