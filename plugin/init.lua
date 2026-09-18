local rime = require "rime_toggle"
rime.setup()

vim.api.nvim_create_user_command("RimeToggle", function()
  rime.toggle()
end, { desc = "Toggle Rime auto ASCII mode" })

vim.api.nvim_create_user_command("RimeEnable", function()
  rime.enable()
end, { desc = "Enable Rime auto ASCII mode" })

vim.api.nvim_create_user_command("RimeDisable", function()
  rime.disable()
end, { desc = "Disable Rime auto ASCII mode" })
