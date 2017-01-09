require 'bosh/director/models/cloud_config'
require 'bosh/director/models/runtime_config'
require 'bosh/director/models/cpi_config'
require 'bosh/director/models/compiled_package'
require 'bosh/director/models/deployment'
require 'bosh/director/models/deployment_problem'
require 'bosh/director/models/deployment_property'
require 'bosh/director/models/director_attribute'
require 'bosh/director/models/instance'
require 'bosh/director/models/ip_address'
require 'bosh/director/models/local_dns_blob'
require 'bosh/director/models/local_dns_record'
require 'bosh/director/models/log_bundle'
require 'bosh/director/models/orphan_disk'
require 'bosh/director/models/orphan_snapshot'
require 'bosh/director/models/package'
require 'bosh/director/models/release'
require 'bosh/director/models/release_version'
require 'bosh/director/models/stemcell'
require 'bosh/director/models/snapshot'
require 'bosh/director/models/task'
require 'bosh/director/models/template'
require 'bosh/director/models/user'
require 'bosh/director/models/persistent_disk'
require 'bosh/director/models/rendered_templates_archive'
require 'bosh/director/models/lock'
require 'bosh/director/models/ephemeral_blob'
require 'bosh/director/models/placeholder_mapping'
require 'delayed_job_sequel'
require 'bosh/director/models/event'
require 'bosh/director/models/agent_dns_version'
require 'bosh/director/models/team'

module Bosh::Director
  module Models
    VALID_ID = /^[-0-9A-Za-z_+.]+$/i

    autoload :Dns, 'bosh/director/models/dns'
  end
end

