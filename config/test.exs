import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :chat_web, ChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zWoSJ5pTTl2I48DO+72zv6ldF/UVDrMTRcdJj7v4NThrPmRwgltCqgox4GGFZF+b",
  server: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :chat_web, ChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3IPay+dmhvmjyDMRwd/7Ov6RfVfwDVDLt3ucxB/XTxJefdtKnBY7/91PiA7jL5o4",
  server: false
