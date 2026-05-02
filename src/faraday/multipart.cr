require "faraday"

require "./multipart/version"
require "./multipart/parts"
require "./multipart/composite_read_io"
require "./multipart/file_part"
require "./multipart/param_part"
require "./multipart/support"
require "./multipart/middleware"
require "./multipart/faraday_ext"

module Faraday
  FilePart        = Multipart::FilePart
  ParamPart       = Multipart::ParamPart
  Parts           = Multipart::Parts
  CompositeReadIO = Multipart::CompositeReadIO
  UploadIO        = Multipart::FilePart
end
