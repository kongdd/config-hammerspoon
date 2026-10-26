require("hs.ipc") -- 临时诊断接口。
powerpoint = require("powerpoint")
minimize = require("minimize")
apps = require("apps")
-- 暂停 Finder 映射：排查 Ctrl/Command 对调冲突及 Del 误删，勿直接启用。
-- finder = require("finder")
