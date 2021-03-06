defmodule Farmbot.Farmware.Installer.Repository.SyncTask do
  @moduledoc """
  Init module for installing first party farmware repo. Requires internet.
  """

  use Task, restart: :transient
  use Farmbot.Logger
  alias Farmbot.System.ConfigStorage
  import ConfigStorage, only: [get_config_value: 3]
  alias Farmbot.Farmware
  alias Farmware.Installer

  @doc false
  def start_link(_) do
    sync_all()
    :ignore
  end

  def bloop do
    File.mkdir_p("/root/farmware_tools")
    url = "https://github.com/FarmBot-Labs/farmware-tools/archive/master.zip"
    zip_file = "/root/farmware-tools.zip"
    {:ok, ^zip_file} = Farmbot.HTTP.download_file(url, zip_file)

    fun = fn({:zip_file, dir, _info, _, _, _}) ->
      [_ | rest] = Path.split(to_string(dir))
      List.first(rest) == "farmware_tools"
    end

    case :zip.extract('/root/farmware-tools.zip', [:memory, file_filter: fun]) do
      {:ok, list} when is_list(list) ->
        Enum.each(list, fn({filename, data}) ->
          out_file = Path.join(["/root", "farmware_tools", Path.basename(to_string(filename))])
          File.write!(out_file, data)
        end)
      {:error, reason} -> raise("Failed do download farmware tools: #{inspect reason}")
    end
  end

  def sync_all do
    Logger.busy 2, "Syncing all Farmware repos. This may take a while."
    setup_repos()

    synced = fetch_and_sync()
    fw_dir = Installer.install_root_path
    if File.exists?(fw_dir) do
      sync_not_in_repos(fw_dir, synced)
    end
  end

  defp setup_repos do
    # first party farmware url could be nil. This would mean it is disabled.
    fpf_url = get_config_value(:string, "settings", "first_party_farmware_url")
    # if fpf_url isn't nil, check if its been enabled, if not enable it.
    if fpf_url do
      unless ConfigStorage.get_farmware_repo_by_url(fpf_url) do
        Installer.add_repo(fpf_url)
      end
    else
      Logger.warn 2, "First party farmware is disabled."
    end
  end

  defp fetch_and_sync do
    repos = ConfigStorage.all_farmware_repos()
    Enum.reduce(repos, [], fn(repo, acc) ->
      case Installer.sync_repo(repo) do
        {:ok, list_of_entries} ->
          Enum.map(list_of_entries, &(Map.get(&1, :name))) ++ acc
        {:error, _} -> acc
      end
    end)
  end

  defp sync_not_in_repos(fw_dir, synced) do
    all_fws = File.ls!(fw_dir)
    not_in_repos = all_fws -- synced
    for fw_name <- not_in_repos do
      case Farmware.lookup(fw_name) do
        {:ok, %Farmware{} = farmware} ->
          Logger.busy 3, "Syncing: #{inspect farmware}"
          Installer.install(farmware.url)
        _ -> :ok
      end
    end
  end

end
