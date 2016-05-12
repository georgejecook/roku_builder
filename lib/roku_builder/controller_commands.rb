module RokuBuilder

  # Commands that the controller uses to interface with the rest of the gem.
  class ControllerCommands

    # Provides a hash of all of the options needed to run simple commands via
    # the simple_command method
    # @return [Hash] options to run simple commands
    def self.simple_commands
      {
        delete: { klass: Loader, method: :unload },
        monitor: { klass: Monitor, method: :monitor,
          config_key: :monitor_config },
        navigate: { klass: Navigator, method: :nav, config_key: :navigate_config,
          failure: FAILED_NAVIGATING },
        screen: { klass: Navigator, method: :screen, config_key: :screen_config,
          failure: FAILED_NAVIGATING },
        key: { klass: Keyer, method: :rekey, config_key: :key },
        screens: { klass: Navigator, method: :screens },
        text: { klass: Navigator, method: :type, config_key: :text_config },
        test: { klass: Tester, method: :run_tests, config_key: :test_config },
        screencapture: { klass: Inspector, method: :screencapture, config_key: :screencapture_config,
          failure: FAILED_SCREENCAPTURE }
      }
    end
    # Validate Config
    # @return [Integer] Success or Failure Code
    def self.validate()
      SUCCESS
    end
    # Run Sideload
    # @param options [Hash] user options
    # @param configs [Hash] parsed configs
    # @return [Integer] Success or Failure Code
    def self.sideload(options:, configs:)
      config = configs[:device_config].dup
      config[:init_params] = configs[:init_params][:loader]
      stager = Stager.new(**configs[:stage_config])
      success = false
      if stager.stage
        loader = Loader.new(**config)
        success = loader.sideload(**configs[:sideload_config])
      end
      stager.unstage
      return FAILED_SIDELOAD unless success
      SUCCESS
    end
    # Run Package
    # @param options [Hash] user options
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.package(options:, configs:, logger:)
      loader_config = configs[:device_config].dup
      loader_config[:init_params] = configs[:init_params][:loader]
      keyer = Keyer.new(**configs[:device_config])
      stager = Stager.new(**configs[:stage_config])
      loader = Loader.new(**loader_config)
      packager = Packager.new(**configs[:device_config])
      inspector = Inspector.new(**configs[:device_config])
      logger.warn "Packaging working directory" if options[:working]
      if stager.stage
        # Sideload #
        build_version = loader.sideload(**configs[:sideload_config])
        return FAILED_SIGNING unless build_version
        # Key #
        success = keyer.rekey(**configs[:key])
        logger.info "Key did not change" unless success
        # Package #
        options[:build_version] = build_version
        configs = ConfigManager.update_configs(configs: configs, options: options)
        success = packager.package(**configs[:package_config])
        logger.info "Signing Successful: #{configs[:package_config][:out_file]}" if success
        return FAILED_SIGNING unless success
        # Inspect #
        if options[:inspect]
          info = inspector.inspect(configs[:inspect_config])
          logger.unknown "App Name: #{info[:app_name]}"
          logger.unknown "Dev ID: #{info[:dev_id]}"
          logger.unknown "Creation Date: #{info[:creation_date]}"
          logger.unknown "dev.zip: #{info[:dev_zip]}"
        end
      end
      stager.unstage
      SUCCESS
    end
    # Run Build
    # @param options [Hash] user options
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.build(options:, configs:, logger:)
      ### Build ###
      loader_config = configs[:device_config].dup
      loader_config[:init_params] = configs[:init_params][:loader]
      stager = Stager.new(**configs[:stage_config])
      loader = Loader.new(**loader_config)
      if stager.stage
        build_version = ManifestManager.build_version(**configs[:manifest_config])
        options[:build_version] = build_version
        configs = ConfigManager.update_configs(configs: configs, options: options)
        outfile = loader.build(**configs[:build_config])
        logger.info "Build: #{outfile}"
      end
      stager.unstage
      SUCCESS
    end
    # Run update
    # @param configs [Hash] parsed configs
    # @param logger [Logger] system logger
    # @return [Integer] Success or Failure Code
    def self.update(configs:, logger:)
      ### Update ###
      stager = Stager.new(**configs[:stage_config])
      if stager.stage
        old_version = ManifestManager.build_version(**configs[:manifest_config])
        new_version = ManifestManager.update_build(**configs[:manifest_config])
        logger.info "Update build version from:\n#{old_version}\nto:\n#{new_version}"
      end
      stager.unstage
      SUCCESS
    end

    # Run Deeplink
    # @param options [Hash] user options
    # @param configs [Hash] parsed configs
    def self.deeplink(options:, configs:)
      sources = options.keys & Controller.sources
      if sources.count > 0
        sideload(options: options, configs: configs)
      end

      linker = Linker.new(configs[:device_config])
      if linker.link(configs[:deeplink_config])
        return SUCCESS
      else
        return FAILED_DEEPLINKING
      end
    end

    # Run a simple command
    # @param klass [Class] class of object to create
    # @param method [Symbol] methog to run on klass
    # @param config_key [Symbol] config to send from configs if not nil
    # @param configs [Hash] parsed roku config
    # @param failure [Integer] failure code to return on failure if not nil
    # @return [Integer] Success of failure code
    def self.simple_command(klass:, method:, config_key: nil, configs:, failure: nil)
      config = configs[:device_config].dup
      key = klass.to_s.split("::")[-1].underscore.to_sym
      if configs[:init_params][key]
        config[:init_params] = configs[:init_params][key]
      end
      instance = klass.new(**config)
      if config_key
        success = instance.send(method, configs[config_key])
      else
        success = instance.send(method)
      end
      return failure unless failure.nil? or success
      SUCCESS
    end
  end
end
