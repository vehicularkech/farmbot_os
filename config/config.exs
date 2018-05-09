use Mix.Config

# Mix configs.
target = Mix.Project.config()[:target]
env = Mix.env()

config :logger, [
  utc_log: true,
  # handle_otp_reports: true,
  # handle_sasl_reports: true,
  backends: [RingLogger]
]

# Stop lager redirecting :error_logger messages
config :lager, :error_logger_redirect, false

# Stop lager removing Logger's :error_logger handler
config :lager, :error_logger_whitelist, []

# Stop lager writing a crash log
config :lager, :crash_log, false

# Use LagerLogger as lager's only handler.
config :lager, :handlers, []

config :elixir, ansi_enabled: true
config :iex, :colors, enabled: true

config :ssl, protocol_version: :"tlsv1.2"

config :farmbot, farm_event_debug_log: false

# Configure your our system.
# Default implementation needs no special stuff.
# See Farmbot.System.Supervisor and Farmbot.System.Init for details.
config :farmbot, :init, []

# Transports.
# See Farmbot.BotState.Transport for details.
config :farmbot, :transport, []

# Configure Farmbot Behaviours.
config :farmbot, :behaviour,
  authorization: Farmbot.Bootstrap.Authorization,
  firmware_handler: Farmbot.Firmware.StubHandler,
  http_adapter: Farmbot.HTTP.HTTPoisonAdapter,
  gpio_handler: Farmbot.System.GPIO.StubHandler

config :farmbot, :farmware,
  first_part_farmware_manifest_url: "https://raw.githubusercontent.com/FarmBot-Labs/farmware_manifests/master/manifest.json"

config :farmbot,
  expected_fw_versions: ["6.4.0.F", "6.4.0.R", "6.4.0.G"],
  firmware_io_logs: false,
  default_server: "https://my.farm.bot"

global_overlay_dir = "rootfs_overlay"

config :nerves, :firmware, rootfs_overlay: [global_overlay_dir]

case target do
  "host" ->
    import_config("host/#{env}.exs")

  _ ->
    custom_rootfs_overlay_dir = "config/target/rootfs_overlay_#{Mix.Project.config[:target]}"
    import_config("target/#{env}.exs")
    if File.exists?("config/target/#{target}.exs"),
      do: import_config("target/#{target}.exs")

    if File.exists?(custom_rootfs_overlay_dir),
      do: config :nerves, :firmware, rootfs_overlay: [global_overlay_dir, custom_rootfs_overlay_dir]
end
