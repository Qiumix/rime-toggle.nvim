local api = vim.api

local rt = {}

local enabled = true
local os_type = nil
local dbus_fn = {}

local last_state_ascii = true
local augroup_name = "RimeAutoMode"
local group = api.nvim_create_augroup(augroup_name, { clear = true })

local os_state = { judged = false, result = false }

local function find_linux_dbus_tool()
  for _, tool in ipairs { "busctl", "basuctl" } do
    if vim.fn.executable(tool) == 1 then
      return tool
    end
  end
  return nil
end

local function init_exec()
  if os_type == "linux" then
    local tool = find_linux_dbus_tool()
    if not tool then
      vim.notify("Rime-DBus: neither busctl nor basuctl found", vim.log.levels.ERROR)
      return false
    end

    dbus_fn.get_state = function()
      local out = vim.fn.system {
        tool,
        "--user",
        "call",
        "org.fcitx.Fcitx5",
        "/rime",
        "org.fcitx.Fcitx.Rime1",
        "IsAsciiMode",
      }
      if vim.v.shell_error ~= 0 then
        return nil
      end
      return out:find("true", 1, true) ~= nil
    end

    dbus_fn.set_state = function(state)
      vim.fn.system {
        tool,
        "--user",
        "call",
        "org.fcitx.Fcitx5",
        "/rime",
        "org.fcitx.Fcitx.Rime1",
        "SetAsciiMode",
        "b",
        state and "true" or "false",
      }
    end
  elseif os_type == "bsd" then
    if vim.fn.executable "dbus-send" ~= 1 then
      vim.notify("Rime-DBus: dbus-send command not found", vim.log.levels.ERROR)
      return false
    end

    dbus_fn.get_state = function()
      local out = vim.fn.system {
        "dbus-send",
        "--session",
        "--dest=org.fcitx.Fcitx5",
        "--print-reply",
        "/rime",
        "org.fcitx.Fcitx.Rime1.IsAsciiMode",
      }
      if vim.v.shell_error ~= 0 then
        return nil
      end
      return out:find("true", 1, true) ~= nil
    end

    dbus_fn.set_state = function(state)
      vim.fn.system {
        "dbus-send",
        "--session",
        "--dest=org.fcitx.Fcitx5",
        "/rime",
        "org.fcitx.Fcitx.Rime1.SetAsciiMode",
        "boolean:" .. (state and "true" or "false"),
      }
    end
  end

  return true
end

local function check_os_and_cmd()
  if os_state.judged then
    return os_state.result
  end
  os_state.judged = true

  if vim.fn.has "linux" == 1 and vim.fn.has "android" ~= 1 then
    os_type = "linux"
  elseif vim.fn.has "bsd" == 1 or vim.fn.has "mac" == 1 then
    os_type = "bsd"
  else
    os_state.result = false
    return false
  end

  os_state.result = init_exec()
  return os_state.result
end

rt.enable = function()
  enabled = true
end

rt.disable = function()
  enabled = false
end

rt.toggle = function()
  enabled = not enabled
end

rt.setup = function(opts)
  os_state.judged = false

  if not check_os_and_cmd() then
    enabled = false
    return
  end

  opts = opts or {}
  if opts.enabled ~= nil then
    enabled = opts.enabled
  end

  api.nvim_clear_autocmds { group = group }

  api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      if not enabled then
        return
      end
      local state = dbus_fn.get_state()
      if state == nil then
        return
      end
      last_state_ascii = state
      if not last_state_ascii then
        dbus_fn.set_state(true)
      end
    end,
    desc = "Ensure physical ASCII mode on leave",
  })

  api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      if not enabled then
        return
      end
      if not last_state_ascii then
        dbus_fn.set_state(last_state_ascii)
      end
    end,
    desc = "Restore previous Rime input state",
  })
end

return rt
