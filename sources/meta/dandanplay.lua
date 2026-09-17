---@meta
-- Generated from dandanplay_swagger.json by tools/gen.py

---@class DandanAPI
local M = {}

-- ===========================================================
-- PATHS
-- ===========================================================

--- ## 获取新番列表
--- `/api/v2/bangumi/shin`
--- ### 接口说明
--- 此接口用于获取官方的新番列表
--- ### 所需权限
--- 当未提供jwt token时，将认为是匿名用户，返回的番剧列表中`isFavorited`始终为`false`。
--- 当提供jwt token时（登录状态），返回的番剧列表中将按照当前用户对番剧关注状态设定`isFavorited`值。
---@param method 'GET'
---@param request { parameters: DandanAPI_Bangumi_GetShinBangumi_Parameters }
---@return DandanAPIBangumiListResponse 200
function M.DandanAPI_Bangumi_GetShinBangumi(method, request) end
---@class DandanAPI_Bangumi_GetShinBangumi_Parameters
---@field filterAdultContent? boolean 是否过滤成人内容 (默认: `false`)

--- ## 获取指定季度中上映的动画番剧
--- `/api/v2/bangumi/season/anime/{year}/{month}`
--- ### 接口说明
--- 此接口用于获取指定季度中上映的动画番剧列表。
--- ### 参数说明
--- Url中的`year`与`month`参数需要先通过`/season/anime`接口获取。
--- 例如2018年只有1、4、7、10四个季度，如果`month`的值不为此四个数字之一将无法获取到对应季度的番剧。
--- ### 所需权限
--- 当未提供jwt token时，将认为是匿名用户，返回的番剧列表中`isFavorited`始终为`false`。
--- 当提供jwt token时（登录状态），返回的番剧列表中将按照当前用户对番剧关注状态设定`isFavorited`值。
---@param method 'GET'
---@param request { parameters: DandanAPI_Bangumi_GetSeasonBangumiOfAnime_Parameters }
---@return DandanAPIBangumiListResponse 200
function M.DandanAPI_Bangumi_GetSeasonBangumiOfAnime(method, request) end
---@class DandanAPI_Bangumi_GetSeasonBangumiOfAnime_Parameters
---@field year int 年份
---@field month int 季度月份（一般指1、4、7、10）
---@field filterAdultContent? boolean 是否过滤成人内容 (默认: `false`)

--- ## 获取动画类型番剧季度的列表
--- `/api/v2/bangumi/season/anime`
---@param method 'GET'
---@param request? table
---@return DandanAPIBangumiSeasonListResponse 200
function M.DandanAPI_Bangumi_GetSeasons(method, request) end

--- ## 获取近期未看番剧的列表
--- `/api/v2/bangumi/queue/intro`
--- ### 接口说明
--- 此接口用户获取用户近期关注但未看/未看完的番剧的列表。
--- ### 权限需求
--- 此接口需要登录状态才可调用。
---@param method 'GET'
---@param request? table
---@return DandanAPIBangumiQueueIntroResponseV2 200
function M.DandanAPI_Bangumi_GetQueueIntro(method, request) end

--- ## 获取完整版未看番剧的列表
--- `/api/v2/bangumi/queue/details`
--- ### 接口说明
--- 此接口用户获取用户完整的未看完的番剧的列表。
--- ### 权限需求
--- 此接口需要登录状态才可调用。
---@param method 'GET'
---@param request? table
---@return DandanAPIBangumiQueueDetailsResponseV2 200
function M.DandanAPI_Bangumi_GetQueueDetails(method, request) end

--- ## 获取番剧详情
--- `/api/v2/bangumi/{bangumiId}`
--- ### 接口说明
--- 此接口用于获取指定编号的作品的详细数据，包括简介、评分、详细剧集等。
--- ### 参数说明
--- `bangumiId`：支持传入数字形式的 animeId（如 18319）或字符串形式的 bangumiId（如 "tmdb-movie-21832"）。
--- ### 所需权限
--- 此接口无需登录状态即可调用。当提供了token时，返回的剧集列表中将包含当前用户的上次播放时间。
---@param method 'GET'
---@param request { parameters: DandanAPI_Bangumi_GetBangumiDetails_Parameters }
---@return DandanAPIBangumiDetailsResponse 200
function M.DandanAPI_Bangumi_GetBangumiDetails(method, request) end
---@class DandanAPI_Bangumi_GetBangumiDetails_Parameters
---@field bangumiId string 作品编号

--- ## 获取指定番剧的短评论/吐槽列表
--- `/api/v2/bangumi/{bangumiId}/comments`
--- ### 接口说明
--- 此接口用于获取指定作品的用户短评论/吐槽列表。
--- ### 参数说明
--- `bangumiId`：支持传入数字形式的 animeId（如 18319）或字符串形式的 bangumiId（如 "tmdb-movie-21832"）。
--- `page`：页码，从0开始。每页固定返回最新20条评论，最多支持到第9页。
--- ### 所需权限
--- 此接口无需登录状态即可调用。
---@param method 'GET'
---@param request { parameters: DandanAPI_Bangumi_GetBangumiComments_Parameters }
---@return DandanAPIBangumiCommentsResponse 200
function M.DandanAPI_Bangumi_GetBangumiComments(method, request) end
---@class DandanAPI_Bangumi_GetBangumiComments_Parameters
---@field bangumiId string 作品编号
---@field page? int 页码，从0开始，最大为9 (默认: `0`)

--- ## 使用Bangumi.tv的subjectId获取番剧详情
--- `/api/v2/bangumi/bgmtv/{bgmtvSubjectId}`
--- ### 接口说明
--- 此接口用于通过Bangumi.tv的subjectId获取番剧详情。
--- 弹弹play和Bangumi.tv番剧条目间的映射关系由人工维护，可能会出现错误、缺失、变动或延迟更新的情况，在使用时请注意。
--- ### 参数说明
--- `bgmtvSubjectId`：Bangumi.tv 的 subjectId，通常是一个整数。例如，网址 https://bangumi.tv/subject/975 中的 `975` 就是subjectId。
--- ### 返回值说明
--- 此接口返回和接口 `/bangumi/{bangumiId}` 相同的结构，包含番剧的详细信息。
--- 当没有找到对应的番剧时，会返回资源未找到错误，bangumi字段将为null。
--- ### 所需权限
--- 此接口无需登录状态即可调用。当提供了token时，返回的剧集列表中将包含当前用户的上次播放时间。
---@param method 'GET'
---@param request { parameters: DandanAPI_Bangumi_GetBangumiDetailsByBgmtvSubjectId_Parameters }
---@return DandanAPIBangumiDetailsResponse 200
function M.DandanAPI_Bangumi_GetBangumiDetailsByBgmtvSubjectId(method, request) end
---@class DandanAPI_Bangumi_GetBangumiDetailsByBgmtvSubjectId_Parameters
---@field bgmtvSubjectId int Bangumi.tv的subjectId

--- ## 获取指定弹幕库的所有弹幕
--- `/api/v2/comment/{episodeId}`
--- ### 接口说明
--- 此接口用于获取服务器上指定弹幕库的弹幕。获取到的弹幕包括弹弹play官方弹幕、第三方网站关联弹幕和开放弹幕网络应用发送的弹幕。
--- ### withRelated 参数
--- 当`withRelated`参数为`true`时，接口将会返回此弹幕库对应的所有第三方关联网址的弹幕。推荐使用此参数获取整合后的弹幕。
--- ### 接口跳转
--- 在调用此接口时，将会跳转到弹幕加速服务上获取弹幕。返回的状态码为302，Location头部包含了跳转的地址。
--- ### 开放弹幕网络应用
--- 当应用使用 `POST /comment/{episodeId}/app` 接口发送弹幕后，再使用此接口获取弹幕时，返回的弹幕中将包含本应用发送的弹幕。
--- 不同应用发送的弹幕将分别存储在不同的私有弹幕库中，互不干扰。
--- ### 返回值
--- 字段`p`的说明：格式为`出现时间,模式,颜色,用户ID`，各个值之间使用英文逗号分隔
--- * 弹幕出现时间：格式为 0.00，单位为秒，精确到小数点后两位，例如12.34、445.6、789.01
--- * 弹幕模式：1-普通弹幕，4-底部弹幕，5-顶部弹幕
--- * 颜色：32位整数表示的颜色，算法为 Rx256x256+Gx256+B，R/G/B的范围应是0-255
--- * 用户ID：字符串形式表示的用户ID，通常为数字，不会包含特殊字符
---@param method 'GET'
---@param request { parameters: DandanAPI_Comment_GetComment_Parameters }
---@return DandanAPICommentResponseV2 302
function M.DandanAPI_Comment_GetComment(method, request) end
---@class DandanAPI_Comment_GetComment_Parameters
---@field episodeId int 弹幕库编号
---@field from? int 起始弹幕编号，忽略此编号以前的弹幕。默认值为`0`。 (默认: `0`)
---@field withRelated? boolean 是否同时获取关联的第三方弹幕。默认值为`false`，推荐使用`true`。 (默认: `false`)
---@field chConvert? int 中文简繁转换。`0`-不转换，`1`-转换为简体，`2`-转换为繁体。 (默认: `0`)

--- ## 向指定的弹幕库发送弹幕
--- `/api/v2/comment/{episodeId}`
--- ### 接口说明
--- 此接口用于弹弹play客户端向服务器的指定弹幕库发送弹幕。
--- 第三方开发者请使用 `/comment/{episodeId}/app` 接口发送弹幕。
--- ### 权限需求
--- 此接口需要用户登录后才可使用
---@param method 'POST'
---@param request { parameters: DandanAPI_Comment_SendComment_Parameters, body: DandanAPI_Comment_SendComment_Body }
---@return DandanAPISendCommentResponseV2 200
---@return nil 401
function M.DandanAPI_Comment_SendComment(method, request) end
---@class DandanAPI_Comment_SendComment_Parameters
---@field episodeId int 弹幕库ID
---@class DandanAPI_Comment_SendComment_Body
---@field time number 弹幕出现时间，单位为秒
---@field mode int 弹幕模式：1-普通弹幕，4-顶部弹幕，5-底部弹幕
---@field color int 弹幕颜色，计算方式为 Rx255x255+Gx255+B
---@field comment? string 弹幕内容，不能长于100个字符

--- ## 向指定弹幕库发送弹幕（开放弹幕网络）
--- `/api/v2/comment/{episodeId}/app`
--- ### 接口说明
--- 此接口用于开放弹幕网络第三方应用开发者向指定弹幕库发送弹幕。
--- 调用方通过 AppId/AppSecret 鉴权，可自行设置用户名，弹幕将与官方弹幕分开存储。
--- 应用使用此接口发送弹幕后，使用 `GET /comment/{episodeId}` 接口获取弹幕时，返回的弹幕中将包含本应用发送的弹幕。
--- 不同应用发送的弹幕将分别存储在不同的私有弹幕库中，互不干扰。
--- ### 权限说明
--- 当前只有`社区合作`和`商业授权`层级的应用有此接口完整额度。其他层级的应用也可以调用此接口，但额度仅限于测试使用。
---@param method 'POST'
---@param request { parameters: DandanAPI_Comment_SendAppComment_Parameters, body: DandanAPI_Comment_SendAppComment_Body }
---@return DandanAPISendCommentResponseV2 200
---@return nil 401
function M.DandanAPI_Comment_SendAppComment(method, request) end
---@class DandanAPI_Comment_SendAppComment_Parameters
---@field episodeId int 弹幕库ID
---@class DandanAPI_Comment_SendAppComment_Body
---@field userName? string 弹幕发送者昵称，由调用方应用自行指定。

--- ## 删除一条应用弹幕（开放弹幕网络）
--- `/api/v2/comment/app/{episodeId}/{cid}`
--- ### 接口说明
--- 此接口用于删除开放弹幕网络应用发送的弹幕。删除后弹幕将从弹幕库中移除，不再被客户端获取到。
--- 弹幕所属应用由调用方的AppId决定，调用方只能删除**自己应用**发送的弹幕。
--- ### 鉴权方式
--- * 必须携带应用凭证：`X-AppId` + `X-Signature` + `X-Timestamp` 签名模式，或 `X-AppId` + `X-AppSecret` 客户端凭证模式
--- ### 返回说明
--- 删除成功时`errorCode`为`0`。当弹幕不存在、已被删除或不属于当前应用时，返回`errorCode=7`（ResourceNotFound）。
--- 删除操作是异步生效的，客户端弹幕缓存可能存在数秒的延迟。
---@param method 'DELETE'
---@param request { parameters: DandanAPI_Comment_DeleteAppComment_Parameters }
---@return DandanAPIResponseBase 200
function M.DandanAPI_Comment_DeleteAppComment(method, request) end
---@class DandanAPI_Comment_DeleteAppComment_Parameters
---@field episodeId int 弹幕库编号
---@field cid int 弹幕编号，即发送弹幕接口返回的`cid`

--- ## 获取当前用户关注的所有动画作品
--- `/api/v2/favorite`
--- ### 接口说明
--- 此接口用于获取用户当前关注的所有动画作品信息
--- ### 权限需求
--- 此接口需要登录状态才能调用
---@param method 'GET'
---@param request { parameters: DandanAPI_Favorite_GetUserFavorite_Parameters }
---@return DandanAPIUserFavoriteResponse 200
---@return nil 401
function M.DandanAPI_Favorite_GetUserFavorite(method, request) end
---@class DandanAPI_Favorite_GetUserFavorite_Parameters
---@field onlyOnAir? boolean 只返回正在连载的作品 (默认: `false`)

--- ## 添加关注
--- `/api/v2/favorite`
--- ### 接口说明
--- 此接口用于为用户增加关注某一部作品。
--- ### 权限需求
--- 此接口需要登录状态才能调用，同时应用应拥有添加关注的权限。
---@param method 'POST'
---@param request { body: DandanAPI_Favorite_AddFavorite_Body }
---@return DandanAPIUserAddFavoriteResponse 200
---@return nil 401
function M.DandanAPI_Favorite_AddFavorite(method, request) end
---@class DandanAPI_Favorite_AddFavorite_Body
---@field animeId int 动画作品编号
---@field favoriteStatus? DandanAPIFavoriteStatus 设定或刷新当前的关注状态。设置为null代表不修改当前状态。
---@field rating int 给作品打分（1-10分），0代表不修改当前分数
---@field comment? string 给作品添加评论，最长为500个字符。当值为null或空字符串时将不修改当前的值。 如果希望清空所有文字，请传入至少一个空格。

--- ## 取消关注
--- `/api/v2/favorite/{animeId}`
--- ### 接口说明
--- 此接口用于为用户取消关注某一部作品。
--- ### 权限需求
--- 此接口需要登录状态才能调用，同时应用应拥有取消关注的权限。
---@param method 'DELETE'
---@param request { parameters: DandanAPI_Favorite_DeleteFavorite_Parameters }
---@return DandanAPIUserDeleteFavoriteResponse 200
---@return nil 401
function M.DandanAPI_Favorite_DeleteFavorite(method, request) end
---@class DandanAPI_Favorite_DeleteFavorite_Parameters
---@field animeId int 作品编号

--- ## 获取整合后的首页数据
--- `/api/v2/homepage`
--- ### 接口说明
--- 此接口用于一次性获取系统公告、未看剧集列表、当季新番列表、热门种子等接口的数据，并合并为同一个文档进行返回。
--- ### 权限需求
--- 当未提供jwt token时，将认为是匿名用户，返回的番剧列表中`isFavorited`始终为`false`。
--- 当提供jwt token时（登录状态），返回的番剧列表中将按照当前用户对番剧关注状态设定`isFavorited`值。
---@param method 'GET'
---@param request { parameters: DandanAPI_Homepage_GetHomepage_Parameters }
---@return DandanAPIHomepageResponseV2 200
function M.DandanAPI_Homepage_GetHomepage(method, request) end
---@class DandanAPI_Homepage_GetHomepage_Parameters
---@field filterAdultContent? boolean 是否过滤可能出现的成人内容 (默认: `false`)

--- ## 获取系统公告
--- `/api/v2/homepage/banner`
---@param method 'GET'
---@param request? table
---@return DandanAPIBannerResponse 200
function M.DandanAPI_Homepage_GetBanner(method, request) end

--- ## 使用用户名密码登录
--- `/api/v2/login`
--- ### 接口说明
--- 通过此接口可以使用用户名/密码获取到后续接口需要的JWT Token。
--- 调用此接口需要有应用的AppId与AppSecret，您可以联系弹弹play开发方申请。
--- ### Hash计算方法
--- Hash属性的计算方法为，将登录请求中 `appId` `password` `unixTimestamp` `userName` 属性的值以及您应用的 `AppSecret` 密钥的值依次拼接起来，
--- 计算出32位MD5（不区分大小写）。举例来说，`appId`为`dandanplay`，AppSecret为`FFFFF`，用户名为`test1`，密码为`test2`，
--- 那么计算方法将会是 `hash=MD5(dandanplaytest2666666666test1FFFFF)`。
--- ### 错误代码
--- 当调用接口发生错误时，例如参数不完整、验证错误、登录失败，`success`属性值将为`false`，`errorCode`代码将不为`0`，
--- 同时`errorMessage`属性将包含错误的描述信息 。
---@param method 'POST'
---@param request { body: DandanAPI_Login_Login_Body }
---@return DandanAPILoginResponse 200
function M.DandanAPI_Login_Login(method, request) end
---@class DandanAPI_Login_Login_Body
---@field userName string 弹弹play用户名
---@field password string 用户密码
---@field appId string 客户端ID
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌。

--- ## 延长已有Token的有效时间
--- `/api/v2/login/renew`
--- ### 接口说明
--- 默认情况下Token的有效期为21天，此接口用于在此期间延长一个有效的JWT Token的有效时间。
--- ### 权限需求
--- 此接口需要登录后才可使用（请求中包含Authorization头）
--- ### 返回值说明
--- 调用此接口后相当于重新使用当前用户的信息进行重新登录，将会返回最新的用户信息（包括已延长有效期的JWT Token）。
--- 如果应用或用户的状态异常，将会返回相应的错误代码。
---@param method 'GET'
---@param request? table
---@return DandanAPILoginResponse 200
---@return nil 401
function M.DandanAPI_Login_RenewToken(method, request) end

--- ## 使用指定的文件名、Hash、文件长度信息寻找文件可能对应的节目信息。
--- `/api/v2/match`
--- ### 接口说明
--- 此接口用于当用户打开某视频文件时，可以通过文件名称、Hash等信息查找此视频可能对应的节目信息。
--- 此接口首先会使用Hash信息进行搜寻，如果有相应的记录，会返回“精确关联”的结果（即`isMatched`属性为`true`，此时列表中只包含一个搜索结果）。
--- 如果Hash信息匹配失败，则会继续通过文件名进行模糊搜寻。
--- ### 返回值说明
--- 一个包含节目信息的列表，节目在列表中排名越靠前，这个节目越有可能是视频文件的内容。
--- 当列表中只有一个节目时（`isMatched`属性为`true`），视为“精确关联” —— 说明此视频已被人工关联了某一节目。客户端应自动选择这个唯一的结果，不必再让用户做出选择。
---@param method 'POST'
---@param request { body: DandanAPI_Match_Match_Body }
---@return DandanAPIMatchResponseV2 200
function M.DandanAPI_Match_Match(method, request) end
---@class DandanAPI_Match_Match_Body
---@field fileName? string 视频文件名，不包含文件夹名称和扩展名，特殊字符需进行转义。
---@field fileHash? string 文件前16MB (16x1024x1024 Byte) 数据的32位MD5结果，不区分大小写。
---@field fileSize int 文件总长度，单位为Byte。
---@field videoDuration int 32位整数的视频时长，单位为秒。默认为0。[可选]
---@field matchMode DandanAPIMatchMode 匹配模式。[可选]

--- ## 使用指定的文件信息批量匹配节目信息
--- `/api/v2/match/batch`
--- ### 接口说明
--- 此接口用于批量匹配（参考`/match`接口），可以通过Hash、文件名称等信息查找多个视频对应的节目信息。
--- 每次批量匹配提供的文件信息不能多于`32`个，文件信息中不能有重复项。
--- 此接口只会返回“精确关联”的结果，如果文件未能成功匹配上一个弹幕库，对应匹配结果的`success`将为`false`。
--- ### 返回值说明
--- 一个包含匹配结果的列表，将与请求中的文件信息一一对应。例如请求中包含了20个文件信息，返回结果的列表中也将包含20个匹配结果。
--- 如果某个文件匹配成功，对应结果的`success`属性将为`true`。如果某文件未匹配成功，或是某个请求未通过验证，对应结果的`success`属性将为`false`。
---@param method 'POST'
---@param request { body: DandanAPI_Match_BatchMatch_Body }
---@return DandanAPIBatchMatchResponse 200
function M.DandanAPI_Match_BatchMatch(method, request) end
---@class DandanAPI_Match_BatchMatch_Body
---@field requests? DandanAPIMatchRequest[] 匹配请求，列表中最多包括32个请求

--- ## 获取用户播放历史
--- `/api/v2/playhistory`
--- ### 接口说明
--- 此接口用于获取用户的播放历史（作品+剧集）。只能获取到用户已关注作品的播放历史。
--- ### 权限需求
--- 此接口需要登录状态才可以调用。
--- ### 开始结束日期参数说明
--- 开始日期不能晚于结束日期；
--- 开始日期与结束日期不能相差大于一年（最多查询一年的数据）；
--- 当没有提供`toDate`参数时，默认将使用当前日期；
--- 当没有提供`fromDate`参数时，默认将使用`toDate`减去三个月的日期。
---@param method 'GET'
---@param request { parameters: DandanAPI_PlayHistory_GetUserPlayHistory_Parameters }
---@return DandanAPIUserPlayHistoryResponse 200
---@return nil 401
function M.DandanAPI_PlayHistory_GetUserPlayHistory(method, request) end
---@class DandanAPI_PlayHistory_GetUserPlayHistory_Parameters
---@field fromDate? string 开始日期
---@field toDate? string 结束日期

--- ## 增加播放历史记录和评分
--- `/api/v2/playhistory`
--- ### 接口说明
--- 此接口用于提交用户的播放历史数据，同时可以更新用户对某剧集的评分。
--- ### 权限需求
--- 此接口需要登录权限才可以调用。
--- ### 参数限制说明
--- 接口支持单个或批量增加历史数据。
--- 提交的请求中，如果`episodeIdList`数组只包含一条数据，则`addToFavorite`参数（关注此作品）和`rating`参数（更新评分）可以生效。
--- 如果`episodeIdList`数组包含不止一条数据，则会忽略`addToFavorite`和`rating`参数。
--- 在批量添加历史记录时，`episodeIdList`数组最多只能包含100条数据，而且其中的episodeId必须全部属于同一部作品。
---@param method 'POST'
---@param request { body: DandanAPI_PlayHistory_AddPlayHistory_Body }
---@return DandanAPIUserAddPlayHistoryResponse 200
---@return nil 401
function M.DandanAPI_PlayHistory_AddPlayHistory(method, request) end
---@class DandanAPI_PlayHistory_AddPlayHistory_Body
---@field episodeIdList? int[] 弹幕库编号列表（最多100项，必须都属于同一作品）
---@field addToFavorite boolean 关注此作品（弹幕库编号列表中必须只有一项）
---@field rating int 给此剧集打分（弹幕库编号列表中必须只有一项）。范围为1-10分，0代表不修改当前评分。

--- ## 注册新的弹弹play用户
--- `/api/v2/register`
--- ### 接口说明
--- 通过此接口可以注册新的弹弹play用户，注册成功后将返回登录结果。
--- 调用此接口需要有应用的AppId与AppSecret，您可以联系弹弹play开发方申请。
--- ### Hash计算方法
--- Hash属性的计算方法为，将登录请求中 `appId` `email` `password` `screenName` `unixTimestamp` `userName` 属性的值加上您应用的 `AppSecret` 密钥的值按顺序拼接起来，
--- 计算出32位MD5（不区分大小写）。举例来说，`appId`为`dandanplay`，AppSecret为`FFFFF`，用户名为`test1`，密码为`test2`，邮箱为`test3@example.com`，昵称为`弹弹`
--- 那么计算方法将会是 `hash=MD5(dandanplaytest3@example.comtest2弹弹666666666test1FFFFF)`。
--- ### 错误代码
--- 当调用接口发生错误时，例如参数不完整、验证错误、登录失败，`success`属性值将为`false`，`errorCode`代码将不为`0`，
--- 同时`errorMessage`属性将包含错误的描述信息 。
---@param method 'POST'
---@param request { body: DandanAPI_Register_RegisterMainUser_Body }
---@return DandanAPILoginResponse 200
function M.DandanAPI_Register_RegisterMainUser(method, request) end
---@class DandanAPI_Register_RegisterMainUser_Body
---@field appId string 客户端ID
---@field userName string 用户名。只能包含英文或数字，长度为5-20位，首位不能为数字。
---@field password string 密码。长度为5到20位之间。
---@field email string 备用邮箱（找回密码用）。长度不能超过50个字符。
---@field screenName string 昵称。长度不能超过50个字符。
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌，不参与旧版Hash计算。

--- ## 重置用户密码
--- `/api/v2/register/resetpassword`
--- ### 接口说明
--- 通过此接口可以重置一个用户的密码至随机密码，重置成功后新的随机密码将会发送到对应的邮箱中。
--- 调用此接口需要有应用的AppId与AppSecret，您可以联系弹弹play开发方申请。
--- ### 请求说明
--- 请求参数中`userName`和`email`必须和注册时的信息完全一致，方能成功重置。
--- 重置密码的请求每2分钟只能发送一次，否则会返回错误信息。
--- ### Hash计算方法
--- Hash属性的计算方法为，将登录请求中 `appId` `email` `unixTimestamp` `userName` 属性的值加上您应用的 `AppSecret` 密钥的值按顺序拼接起来，
--- 计算出32位MD5（不区分大小写）。举例来说，`appId`为`dandanplay`，AppSecret为`FFFFF`，用户名为`test1`，邮箱为`test3@example.com`，
--- 那么计算方法将会是 `hash=MD5(dandanplaytest3@example.com666666666test1FFFFF)`。
--- ### 错误代码
--- 当调用接口发生错误时，例如参数不完整、验证错误、登录失败，`success`属性值将为`false`，`errorCode`代码将不为`0`，
--- 同时`errorMessage`属性将包含错误的描述信息 。
---@param method 'POST'
---@param request { body: DandanAPI_Register_ResetPassword_Body }
---@return DandanAPIResetPasswordResponseV2 200
function M.DandanAPI_Register_ResetPassword(method, request) end
---@class DandanAPI_Register_ResetPassword_Body
---@field appId string 应用ID
---@field userName string 用户名
---@field email string 注册此用户时填写的备用邮箱
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌，不参与旧版Hash计算。

--- ## 查找邮箱对应的用户名
--- `/api/v2/register/findmyid`
--- ### 接口说明
--- 通过此接口可以查找一个指定邮箱对应的用户名，查找结果将会发送到对应的邮箱中。
--- 调用此接口需要有应用的AppId与AppSecret，您可以联系弹弹play开发方申请。
--- ### 请求说明
--- 请求参数中`email`必须和注册时的信息完全一致，方能查找成功。
--- 查找用户名的请求每`10`分钟只能发送一次，否则会返回错误信息。
--- ### Hash计算方法
--- Hash属性的计算方法为，将登录请求中 `appId` `email` `unixTimestamp` 属性的值加上您应用的 `AppSecret` 密钥的值按顺序拼接起来，
--- 计算出32位MD5（不区分大小写）。举例来说，`appId`为`dandanplay`，AppSecret为`FFFFF`，邮箱为`test3@example.com`，
--- 那么计算方法将会是 `hash=MD5(dandanplaytest3@example.com666666666FFFFF)`。
--- ### 错误代码
--- 当调用接口发生错误时，例如参数不完整、验证错误、登录失败，`success`属性值将为`false`，`errorCode`代码将不为`0`，
--- 同时`errorMessage`属性将包含错误的描述信息 。
---@param method 'POST'
---@param request { body: DandanAPI_Register_FindMyId_Body }
---@return DandanAPIFindMyIdResponse 200
function M.DandanAPI_Register_FindMyId(method, request) end
---@class DandanAPI_Register_FindMyId_Body
---@field appId string 应用ID
---@field email string 注册此用户时填写的备用邮箱
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌，不参与旧版Hash计算。

--- ## 根据关键词搜索作品
--- `/api/v2/search/anime`
--- ### 接口说明
--- 根据用户提供的关键词，在弹弹play数据库中搜索对应的作品信息，搜索结果中不包含剧集信息。
--- ### 权限需求
--- 不需要登录状态即可使用
--- ### 关键词说明
--- * 关键词长度至少为`2`。
--- * 关键词中的空格将被认定为 AND 条件，其他字符将被作为原始字符去搜索。
--- * 可以通过中文、日文、罗马音、英文等条件对作品的别名进行搜索，繁体中文关键词将被统一为简体中文。
---@param method 'GET'
---@param request { parameters: DandanAPI_Search_SearchAnime_Parameters }
---@return DandanAPISearchAnimeResponse 200
function M.DandanAPI_Search_SearchAnime(method, request) end
---@class DandanAPI_Search_SearchAnime_Parameters
---@field keyword string 作品标题关键词。
---@field type? DandanAPIAnimeType 可选的作品类型。
---@field v2? boolean 提供 true 时使用新版搜索引擎。默认为`false`。

--- ## 根据关键词搜索TMDB中的作品
--- `/api/v2/search/tmdb`
--- ### 接口说明
--- 根据用户提供的关键词，在TMDB数据库中搜索作品，搜索结果中不包含剧集信息。
--- ### 权限需求
--- 不需要登录状态即可使用
--- ### 关键词说明
--- * 关键词长度至少为`2`。
--- * 可以通过中文、日文、罗马音、英文等条件对作品的别名进行搜索。
--- ### 返回结果
--- 返回结果中将包含TMDB电视剧和电影的搜索结果。电视剧结果排列在前，电影将排列在后。
---@param method 'GET'
---@param request { parameters: DandanAPI_Search_SearchTmdb_Parameters }
---@return DandanAPISearchAnimeResponse 200
function M.DandanAPI_Search_SearchTmdb(method, request) end
---@class DandanAPI_Search_SearchTmdb_Parameters
---@field keyword string

--- ## 根据关键词搜索所有匹配的剧集信息
--- `/api/v2/search/episodes`
--- ### 接口说明
--- 此接口用于根据关键词搜索所有匹配的剧集信息。
--- 当自动匹配失败或结果不理想时可以调用此接口，让用户手动通过关键词搜索到作品。
--- ### 参数说明
--- - anime：作品标题。支持通过中文、日语（含罗马音）、英语搜索，至少为2个字符。
--- - tmdbId：使用 TMDB 电视剧 ID 搜索作品，如果指定此参数，将仅返回此 TMDB TV ID 的关联作品（可能有多个）。
--- - tmdbIdType: 指定 tmdbId 的类型，0或不提供表示tmdbId为电视剧ID，1表示tmdbId为电影ID。
--- - episode：剧集编号，默认为空。支持正整数或 C1/S1/O1 格式，将仅保留指定集数的结果；其他值将被忽略。
--- - v2：提供 true 时使用新版搜索引擎。
--- 必须提供`anime`和`tmdbId`中至少一个参数。
--- 当同时提供`anime`和`tmdbId`参数时，会先尝试使用`anime`参数进行搜索，之后在搜索结果中匹配`tmdbId`的剧集。
--- ### 参数注意事项
--- * 参数可以包含空格，但空格将作为查询字符串的一部分而不是传统的“OR”查询。
--- * 未提供`episode`参数的情况下，如果`anime`参数中包含空格，且空格后为数字（如“EVA 10”），此数字将被认定为是`episode`参数。
--- * 如果参数中包含特殊字符，需要经过Url编码后才能传递。
--- ### 返回值说明
--- 接口将返回包含节目信息的列表，当结果集过大时，`hasMore`属性为`true`，这时客户端应该提示用户填写更详细的信息以缩小搜索范围。
---@param method 'GET'
---@param request { parameters: DandanAPI_Search_SearchEpisodes_Parameters }
---@return DandanAPISearchEpisodesResponse 200
---@return nil 401
function M.DandanAPI_Search_SearchEpisodes(method, request) end
---@class DandanAPI_Search_SearchEpisodes_Parameters
---@field anime? string 作品标题。支持通过中文、日语（含罗马音）、英语搜索，至少为2个字符。
---@field tmdbId? int TMDB ID，如果指定此参数，将仅返回此 TMDB ID 的关联作品（可能有多个）。
---@field tmdbIdType? int 指定 tmdbId 的类型，0或不提供表示tmdbId为电视剧ID，1表示tmdbId为电影ID。 (默认: `0`)
---@field episode? string 剧集编号，默认为空。支持正整数或 C1/S1/O1 格式，将仅保留指定集数的结果。 其他值将被忽略。
---@field v2? boolean 提供 true 时使用新版搜索引擎。默认为`false`。

--- ## 根据标签搜索最匹配的作品
--- `/api/v2/search/tag`
--- ### 接口说明
--- 根据用户提供的标签列表搜索到对应的作品信息，搜索结果中不包含剧集信息。
--- ### 权限需求
--- 不需要登录状态即可使用。返回中的`isFavorited`属性目前都为`false`。
--- ### 返回值
--- 将返回根据提供的标签列表最匹配的作品列表。
--- ### 标签说明
--- 支持查询多个标签，标签之间用英文逗号分隔。每个标签的长度不超过50个字符。标签数量不超过10个。
--- 标签将区分大小写，且不支持模糊查询。
---@param method 'GET'
---@param request { parameters: DandanAPI_Search_SearchAnimeByTag_Parameters }
---@return DandanAPISearchBangumiResponse 200
function M.DandanAPI_Search_SearchAnimeByTag(method, request) end
---@class DandanAPI_Search_SearchAnimeByTag_Parameters
---@field tags string 标签列表。

--- ## 获取高级搜索默认配置
--- `/api/v2/search/adv/config`
--- ### 接口说明
--- 获取高级搜索功能所需的配置项，用于初始化客户端搜索界面。例如类别、标签等。
--- ### 权限需求
--- 不需要登录状态即可使用。
---@param method 'GET'
---@param request { parameters: DandanAPI_Search_GetSearchAdvConfig_Parameters }
---@return DandanAPISearchAdvancedConfigResponse 200
function M.DandanAPI_Search_GetSearchAdvConfig(method, request) end
---@class DandanAPI_Search_GetSearchAdvConfig_Parameters
---@field source? string (默认: `'anidb'`)

--- ## 高级搜索
--- `/api/v2/search/adv`
---@param method 'GET'
---@param request { parameters: DandanAPI_Search_SearchAdvanced_Parameters }
---@return DandanAPISearchBangumiResponse 200
function M.DandanAPI_Search_SearchAdvanced(method, request) end
---@class DandanAPI_Search_SearchAdvanced_Parameters
---@field source? string 数据源。anidb|tmdb。默认为anidb
---@field keyword? string 作品标题关键词
---@field type? int 作品类型
---@field tags? string 标签，一个或多个数字。若填写多个数字请用英文逗号隔开，例如 12,34,56 。设定多个数字时将搜索同时包含这些标签的作品。
---@field year? int 限定作品上映的年份
---@field month? int 限定年份前提下继续限定作品月份
---@field minRate? int 限定最低评分（包含） (默认: `0`)
---@field maxRate? int 限定最高评分（包含） (默认: `10`)
---@field restricted? boolean 只显示限制级别的内容。不提供此参数则不过滤结果，提供true或false都将过滤结果。
---@field sort? int 设定排序规则 (默认: `0`)
---@field v2? boolean 提供 true 且数据源为 anidb 时使用新版搜索引擎。默认为`false`。

--- ## 获取全站热播榜
--- `/api/v2/trending/all/hot/{period}`
--- ### 接口说明
--- 返回最近一个可用统计周期内的全站热播榜数据。
--- ### 数据口径
--- 榜单的热度值来自弹幕库访问计数的按日汇总结果。
--- ### 所需权限
--- 当未提供 jwt token 时，将认为是匿名用户，返回的番剧列表中 `isFavorited` 始终为 `false`。
--- 当提供 jwt token 时（登录状态），返回的番剧列表中将按照当前用户对番剧关注状态设定 `isFavorited` 值。
--- ### 数据出处说明
--- 使用此榜单数据时，请注明数据来源为`弹弹play开放弹幕网络`。
---@param method 'GET'
---@param request { parameters: DandanAPI_Trending_GetHotBangumi_Parameters }
---@return DandanAPITrendingBangumiResponse 200
function M.DandanAPI_Trending_GetHotBangumi(method, request) end
---@class DandanAPI_Trending_GetHotBangumi_Parameters
---@field period string 统计周期。可选值：week、month、quarter
---@field filterAdultContent? boolean 是否过滤成人内容 (默认: `false`)
---@field limit? int 返回条目数量，默认20，最大50 (默认: `20`)

--- ## 获取全站飙升榜
--- `/api/v2/trending/all/rising/{period}`
--- ### 接口说明
--- 返回最近一个可用统计周期内，相比上一对应周期热度增长最快的番剧列表。
--- ### 数据口径
--- 飙升榜会综合当前周期热度值与相对上一周期的热度增量计算得分，用于识别最近快速升温的作品。
--- ### 所需权限
--- 当未提供 jwt token 时，将认为是匿名用户，返回的番剧列表中 `isFavorited` 始终为 `false`。
--- 当提供 jwt token 时（登录状态），返回的番剧列表中将按照当前用户对番剧关注状态设定 `isFavorited` 值。
--- ### 数据出处说明
--- 使用此榜单数据时，请注明数据来源为`弹弹play开放弹幕网络`。
---@param method 'GET'
---@param request { parameters: DandanAPI_Trending_GetRisingBangumi_Parameters }
---@return DandanAPITrendingBangumiResponse 200
function M.DandanAPI_Trending_GetRisingBangumi(method, request) end
---@class DandanAPI_Trending_GetRisingBangumi_Parameters
---@field period string 统计周期。可选值：week、month、quarter
---@field filterAdultContent? boolean 是否过滤成人内容 (默认: `false`)
---@field limit? int 返回条目数量，默认20，最大50 (默认: `20`)

--- ## 获取新番热播榜
--- `/api/v2/trending/new-anime/hot/{scope}`
--- ### 接口说明
--- 返回指定范围内的新番热播榜数据，支持本季新番、上一季度新番两种榜单。
--- ### 数据口径
--- 榜单会先按作品首播时间筛选出对应范围内的新番，再根据对应统计周期内的站内热度进行排序。
--- ### 所需权限
--- 当未提供 jwt token 时，将认为是匿名用户，返回的番剧列表中 `isFavorited` 始终为 `false`。
--- 当提供 jwt token 时（登录状态），返回的番剧列表中将按照当前用户对番剧关注状态设定 `isFavorited` 值。
--- ### 数据出处说明
--- 使用此榜单数据时，请注明数据来源为`弹弹play开放弹幕网络`。
---@param method 'GET'
---@param request { parameters: DandanAPI_Trending_GetNewAnimeHotBangumi_Parameters }
---@return DandanAPITrendingBangumiResponse 200
function M.DandanAPI_Trending_GetNewAnimeHotBangumi(method, request) end
---@class DandanAPI_Trending_GetNewAnimeHotBangumi_Parameters
---@field scope string 榜单范围。可选值：current-season、previous-season
---@field filterAdultContent? boolean 是否过滤成人内容 (默认: `false`)
---@field limit? int 返回条目数量，默认20，最大50 (默认: `20`)

--- ## 获取当前 User OAuth 会话对应的用户资料。
--- `/api/v2/user/me`
--- 此接口用于新版客户端在完成 OAuth token 兑换后初始化用户状态。
--- 响应不包含旧 JWT、数字 token 或其他登录凭据。
---@param method 'GET'
---@param request? table
---@return DandanAPIUserProfileResponse 200
---@return nil 401
---@return nil 403
function M.DandanAPI_User_GetCurrentUser(method, request) end

--- ## 为已登录用户修改密码
--- `/api/v2/user/password`
--- ### 接口说明
--- 此接口用于为已经登录的用户修改当前的登录密码。
--- ### 权限需求
--- 此接口需要登录后才可使用（请求中包含Authorization头）
---@param method 'POST'
---@param request { body: DandanAPI_User_UpdatePassword_Body }
---@return DandanAPIUserUpdateProfileResponseV2 200
---@return nil 401
function M.DandanAPI_User_UpdatePassword(method, request) end
---@class DandanAPI_User_UpdatePassword_Body
---@field oldPassword string 旧密码（5-20位）
---@field newPassword string 新密码（5-20位）

--- ## 修改用户资料（昵称、头像等）
--- `/api/v2/user/profile`
--- ### 接口说明
--- 此接口用于为已经登录的用户修改当前的基本资料（如昵称、头像）。
--- 当提供`screenName`时才更新昵称，提供`profileImageBase64`时才更新头像图片，否则不会产生变化。
--- ### 更新头像图片
--- 头像图片需要转换成base64编码后放入`profileImageBase64`字段中。此字段长度不能超过1MB。
--- 上传的图片将保留长宽比，转换为边长最长600px的长方形，并存储为jpg格式。
--- ### 权限需求
--- 此接口需要登录后才可使用（请求中包含Authorization头）
---@param method 'POST'
---@param request { body: DandanAPI_User_UpdateProfile_Body }
---@return DandanAPIUserUpdateProfileResponseV2 200
---@return nil 401
function M.DandanAPI_User_UpdateProfile(method, request) end
---@class DandanAPI_User_UpdateProfile_Body
---@field screenName? string 用户新的昵称（留空将不修改昵称）
---@field profileImageBase64? string 用户头像图片使用Base64编码后的数据（jpg格式，长度不能超过1MB）。留空将不修改头像图片

--- ## 为已登录用户修改关联邮箱
--- `/api/v2/user/email`
--- ### 接口说明
--- 此接口用于为已经登录的用户修改当前账号关联的邮箱地址。
--- ### 权限需求
--- 此接口需要登录后才可使用（请求中包含Authorization头）
---@param method 'POST'
---@param request { body: DandanAPI_User_UpdateUserEmail_Body }
---@return DandanAPIUserUpdateProfileResponseV2 200
---@return nil 401
function M.DandanAPI_User_UpdateUserEmail(method, request) end
---@class DandanAPI_User_UpdateUserEmail_Body
---@field oldEmail string 当前的关联邮箱地址
---@field newEmail string 新的关联邮箱地址

-- ===========================================================
-- COMPONENTS
-- ===========================================================

---@class DandanAPIBangumiListResponse : DandanAPIResponseBase
---@field bangumiList? DandanAPIBangumiIntro[] 番剧列表

---@class DandanAPIBangumiIntro
---@field animeId int 作品编号
---@field bangumiId? string 作品ID（新）
---@field animeTitle? string 作品标题
---@field imageUrl? string 海报图片地址
---@field searchKeyword? string 搜索关键词
---@field isOnAir boolean 是否正在连载中
---@field airDay int 周几上映，0代表周日，1-6代表周一至周六
---@field isFavorited boolean 当前用户是否已关注（无论是否为已弃番等附加状态）
---@field isRestricted boolean 是否为限制级别的内容（例如属于R18分级）
---@field rating number 番剧综合评分（综合多个来源的评分求出的加权平均值，0-10分）

---@class DandanAPIResponseBase
---@field errorCode int 错误代码，0表示没有发生错误，非0表示有错误，详细信息会包含在errorMessage属性中
---@field success boolean 接口是否调用成功
---@field errorMessage? string 当发生错误时，说明错误具体原因
---@field errorDetail? string 当参数校验失败时，提供可供调用方定位问题字段的补充信息。

---@class DandanAPIBangumiSeasonListResponse : DandanAPIResponseBase
---@field seasons? DandanAPIBangumiSeason[] 番剧季度列表

---@class DandanAPIBangumiSeason
---@field year int 年份
---@field month int 月份
---@field seasonName? string 季度名称

---@class DandanAPIBangumiQueueIntroResponseV2 : DandanAPIResponseBase
---@field hasMore boolean 是否有更多数据可以展示（显示界面上的“更多”按钮）
---@field bangumiList? DandanAPIBangumiQueueIntroV2[] 未看剧集列表

---@class DandanAPIBangumiQueueIntroV2
---@field animeId int 作品编号
---@field animeTitle? string 作品标题
---@field episodeTitle? string 最新一集的剧集标题
---@field airDate? string 剧集上映日期（无小时分钟，当地时间）
---@field imageUrl? string 海报图片地址
---@field description? string 未看状态的说明，如“今天更新”，“昨天更新”，“有多集未看”等
---@field isOnAir boolean 番剧是否在连载中

---@class DandanAPIBangumiQueueDetailsResponseV2 : DandanAPIResponseBase
---@field bangumiList? DandanAPIBangumiQueueDetailsV2[] 未看番剧剧集列表
---@field unwatchedBangumiList? DandanAPIBangumiQueueDetailsV2[] 已关注但从未看过的番剧列表

---@class DandanAPIBangumiQueueDetailsV2
---@field animeId int 作品编号
---@field animeTitle? string 作品标题
---@field isOnAir boolean 是否正在连载中
---@field imageUrl? string 海报图片地址
---@field searchKeyword? string 搜索资源的关键词
---@field lastWatched? string 上次观看时间（null表示尚未看过）
---@field episodes? DandanAPIBangumiQueueEpisodeV2[] 未看剧集的列表

---@class DandanAPIBangumiQueueEpisodeV2
---@field episodeId int 剧集编号（弹幕库编号）
---@field episodeTitle? string 剧集标题
---@field airDate? string 上映日期（无小时分钟，当地时间），可能为null

---@class DandanAPIBangumiDetailsResponse : DandanAPIResponseBase
---@field bangumi? DandanAPIBangumiDetails 番剧详情

---@class DandanAPIBangumiDetails : DandanAPIBangumiIntro
---@field type DandanAPIAnimeType 作品类型
---@field typeDescription? string 类型描述
---@field titles? DandanAPIBangumiTitle[] 作品标题
---@field seasons? DandanAPIBangumiEpisodeSeason[] 作品季度列表。可能为空，仅对部分源（如TMDB源）有效
---@field episodes? DandanAPIBangumiEpisode[] 剧集列表
---@field summary? string 番剧简介
---@field intro? string 短简介（Staff简介或剧情简介）
---@field metadata? string[] 番剧元数据（名称、制作人员、配音人员等）
---@field bangumiUrl? string Bangumi.tv页面地址
---@field userRating int 用户个人评分（0-10）
---@field favoriteStatus? DandanAPIFavoriteStatus 关注状态
---@field comment? string 用户对此番剧的备注/评论/标签
---@field ratingDetails? table<string, any> 各个站点的评分详情
---@field relateds? DandanAPIBangumiIntro[] 与此作品直接关联的其他作品（例如同一作品的不同季、剧场版、OVA等）
---@field similars? DandanAPIBangumiIntro[] 与此作品相似的其他作品
---@field tags? DandanAPIBangumiTag[] 标签列表
---@field onlineDatabases? DandanAPIBangumiOnlineDatabase[] 此作品在其他在线数据库/网站的对应url
---@field trailers? DandanAPIBangumiTrailer[] 预告片列表

---@alias DandanAPIAnimeType
--- | 'tvseries'
--- | 'tvspecial'
--- | 'ova'
--- | 'movie'
--- | 'musicvideo'
--- | 'web'
--- | 'other'
--- | 'jpmovie'
--- | 'jpdrama'
--- | 'unknown'
--- | 'tmdbtv'
--- | 'tmdbmovie'

---@class DandanAPIBangumiTitle
---@field language? string 语言
---@field title? string 标题

---@class DandanAPIBangumiEpisodeSeason
---@field id? string 季度ID
---@field airDate? string 上映日期
---@field name? string 季度名称
---@field episodeCount int 剧集数量
---@field summary? string 季度简介

---@class DandanAPIBangumiEpisode
---@field seasonId? string 季度ID（如果为空表示只有一个季度）
---@field episodeId int 剧集ID（弹幕库编号）
---@field episodeTitle? string 剧集完整标题
---@field episodeNumber? string 剧集短标题（可以用来排序，非纯数字，可能包含字母）
---@field lastWatched? string 上次观看时间（服务器时间，即北京时间）
---@field airDate? string 本集上映时间（当地时间）

---@alias DandanAPIFavoriteStatus
--- | 'favorited'
--- | 'finished'
--- | 'abandoned'

---@class DandanAPIBangumiTag
---@field id int 标签编号
---@field name? string 标签内容
---@field count int 观众为此标签+1次数

---@class DandanAPIBangumiOnlineDatabase
---@field name? string 网站名称
---@field url? string 网址

---@class DandanAPIBangumiTrailer
---@field id int 视频编号
---@field url? string 视频播放页地址
---@field title? string 视频标题
---@field imageUrl? string 视频封面
---@field date string 发布时间

---@class DandanAPIBangumiCommentsResponse : DandanAPIResponseBase
---@field count int 当前页返回的评论数量
---@field hasMore boolean 是否还有更多评论可以获取
---@field comments? DandanAPIBangumiComment[] 评论列表

---@class DandanAPIBangumiComment
---@field id int 评论编号
---@field userId int 弹弹play 用户ID。为 0 表示非本平台用户
---@field externalUserId? string 外部平台用户ID/主页标识
---@field userName? string 用户名
---@field imageUrl? string 用户头像地址
---@field source? string 评论来源，例如 Bangumi
---@field text? string 评论内容
---@field rating int 用户评分（0-10）
---@field updatedTime string 记录更新时间

---@class DandanAPICommentResponseV2
---@field count int 弹幕数量
---@field comments? DandanAPICommentData[] 弹幕列表

---@class DandanAPICommentData
---@field cid int 弹幕ID
---@field p? string 弹幕参数（出现时间,模式,颜色,用户ID）
---@field m? string 弹幕内容

---@class DandanAPISendCommentResponseV2 : DandanAPIResponseBase
---@field cid int 此弹幕库中的弹幕ID

---@class DandanAPISendCommentRequest
---@field time number 弹幕出现时间，单位为秒
---@field mode int 弹幕模式：1-普通弹幕，4-顶部弹幕，5-底部弹幕
---@field color int 弹幕颜色，计算方式为 Rx255x255+Gx255+B
---@field comment? string 弹幕内容，不能长于100个字符

---@class DandanAPISendAppCommentRequest : DandanAPISendCommentRequest
---@field userName? string 弹幕发送者昵称，由调用方应用自行指定。

---@class DandanAPIUserFavoriteResponse : DandanAPIResponseBase
---@field favorites? DandanAPIUserFavoriteItem[] 关注列表

---@class DandanAPIUserFavoriteItem
---@field animeId int 作品编号
---@field bangumiId? string 作品编号
---@field animeTitle? string 作品标题
---@field type DandanAPIAnimeType 作品类型
---@field lastFavoriteTime string 上次关注的时间
---@field lastAirDate? string 上次剧集更新的时间
---@field lastWatchTime? string 上次播放作品相关剧集的时间
---@field imageUrl? string 海报图片地址
---@field episodeTotal int 此作品的总集数
---@field episodeWatched int 当前已看的集数
---@field startDate? string 番剧首话上映日期
---@field isOnAir boolean 此作品是否正在连载中
---@field favoriteStatus DandanAPIFavoriteStatus 关注状态
---@field userRating int 用户给此作品的评分（1-10分，0代表未评分）
---@field rating number 此番剧的综合评分（0-10分）

---@class DandanAPIUserAddFavoriteResponse : DandanAPIResponseBase

---@class DandanAPIUserAddFavoriteRequest
---@field animeId int 动画作品编号
---@field favoriteStatus? DandanAPIFavoriteStatus 设定或刷新当前的关注状态。设置为null代表不修改当前状态。
---@field rating int 给作品打分（1-10分），0代表不修改当前分数
---@field comment? string 给作品添加评论，最长为500个字符。当值为null或空字符串时将不修改当前的值。 如果希望清空所有文字，请传入至少一个空格。

---@class DandanAPIUserDeleteFavoriteResponse : DandanAPIResponseBase

---@class DandanAPIHomepageResponseV2 : DandanAPIResponseBase
---@field banners? DandanAPIBannerPageItem[] 公告列表
---@field bangumiQueueIntroList? DandanAPIBangumiQueueIntroV2[] 未看剧集列表
---@field shinBangumiList? DandanAPIBangumiIntro[] 新番列表
---@field bangumiSeasons? DandanAPIBangumiSeason[] 动画番剧季度列表

---@class DandanAPIBannerPageItem
---@field id int 公告ID
---@field title? string 标题
---@field description? string 子标题、描述
---@field url? string 落地页链接
---@field imageUrl? string 图片地址

---@class DandanAPIBannerResponse : DandanAPIResponseBase
---@field banners? DandanAPIBannerPageItem[] 公告列表

---@class DandanAPILoginResponse : DandanAPIResponseBase
---@field registerRequired boolean 该用户是否需要先注册弹弹play账号才可正常登录。当此值为true时表示用户使用了QQ微博等第三方登录但没有注册弹弹play账号。
---@field userId int 用户编号
---@field userName? string 弹弹play用户名。如果用户使用第三方账号登录（如QQ微博）且没有关联弹弹play账号，此属性将为null
---@field email? string 用户邮箱地址
---@field legacyTokenNumber int 旧API中使用的数字形式的token，仅为兼容性设置，不要在新代码中使用此属性
---@field token? string 字符串形式的JWT token。将来调用需要验证权限的接口时，需要在HTTP Authorization头中设置“Bearer token”。
---@field tokenExpireTime string JWT token过期时间，默认为21天。如果是APP应用开发者账号使用自己的应用登录则为1年。
---@field userType? string 用户注册来源类型
---@field screenName? string 昵称
---@field profileImage? string 头像图片的地址
---@field appScope? string 当前登录会话内应用权限列表，可以由此判断能否调用哪些API
---@field payConfigs? DandanAPIPayConfig[] 商品列表
---@field privileges? DandanAPIUserPrivileges 用户权益过期时间（全部为北京时间）
---@field code? string 消息体验证码
---@field ts int 当前时间戳
---@field linkedAccounts? DandanAPILinkedAccounts 已关联的第三方账号信息（如 bangumi.tv 账号）

---@class DandanAPIPayConfig
---@field providerId? string 支付渠道（wechat,alipay）
---@field providerName? string 支付渠道名称（微信支付，支付宝）
---@field items? DandanAPIPayConfigItem[] 商品列表

---@class DandanAPIPayConfigItem
---@field id? string 商品ID
---@field name? string 商品名称（如：1个月会员）
---@field price int 商品价格（单位：分）
---@field currency? string 货币单位（CNY）

---@class DandanAPIUserPrivileges
---@field member? string 会员权益过期时间（北京时间）
---@field resmonitor? string 弹弹play资源监视器权益过期时间（北京时间）

---@class DandanAPILinkedAccounts
---@field bangumi? DandanAPILinkedAccountInfo bangumi.tv 用户

---@class DandanAPILinkedAccountInfo
---@field userId? string bangumi.tv 用户ID
---@field userName? string bangumi.tv 用户名
---@field display? string 显示名称（昵称）
---@field avatar? string 用户头像URL
---@field expires string 当前授权过期时间（北京时间）

---@class DandanAPILoginRequest
---@field userName string 弹弹play用户名
---@field password string 用户密码
---@field appId string 客户端ID
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌。

---@class DandanAPIMatchResponseV2 : DandanAPIResponseBase
---@field isMatched boolean 是否已精确关联到某个弹幕库
---@field matches? DandanAPIMatchResultV2[] 搜索匹配的结果

---@class DandanAPIMatchResultV2
---@field episodeId int 弹幕库ID
---@field animeId int 作品ID
---@field animeTitle? string 作品标题
---@field episodeTitle? string 剧集标题
---@field type DandanAPIAnimeType 作品类别
---@field typeDescription? string 类型描述
---@field shift number 弹幕偏移时间（弹幕应延迟多少秒出现）。此数字为负数时表示弹幕应提前多少秒出现。
---@field imageUrl? string 此作品的海报图片地址

---@class DandanAPIMatchRequest
---@field fileName? string 视频文件名，不包含文件夹名称和扩展名，特殊字符需进行转义。
---@field fileHash? string 文件前16MB (16x1024x1024 Byte) 数据的32位MD5结果，不区分大小写。
---@field fileSize int 文件总长度，单位为Byte。
---@field videoDuration int 32位整数的视频时长，单位为秒。默认为0。[可选]
---@field matchMode DandanAPIMatchMode 匹配模式。[可选]

---@alias DandanAPIMatchMode
--- | 'hashAndFileName'
--- | 'fileNameOnly'
--- | 'hashOnly'

---@class DandanAPIBatchMatchResponse : DandanAPIResponseBase
---@field results? DandanAPIBatchMatchResponseItem[] 批量匹配的结果。将针对每个请求生成对应的结果。

---@class DandanAPIBatchMatchResponseItem
---@field success boolean
---@field fileHash? string
---@field matchResult? DandanAPIMatchResultV2

---@class DandanAPIBatchMatchRequest
---@field requests? DandanAPIMatchRequest[] 匹配请求，列表中最多包括32个请求

---@class DandanAPIUserPlayHistoryResponse : DandanAPIResponseBase
---@field playHistoryAnimes? DandanAPIUserPlayHistoryAnime[]

---@class DandanAPIUserPlayHistoryAnime
---@field animeId int
---@field animeTitle? string
---@field type DandanAPIAnimeType 作品类别
---@field typeDescription? string 类型描述
---@field imageUrl? string
---@field isOnAir boolean
---@field episodes? DandanAPIBangumiEpisode[]

---@class DandanAPIUserAddPlayHistoryResponse : DandanAPIResponseBase

---@class DandanAPIUserAddPlayHistoryRequest
---@field episodeIdList? int[] 弹幕库编号列表（最多100项，必须都属于同一作品）
---@field addToFavorite boolean 关注此作品（弹幕库编号列表中必须只有一项）
---@field rating int 给此剧集打分（弹幕库编号列表中必须只有一项）。范围为1-10分，0代表不修改当前评分。

---@class DandanAPIRegisterRequestV2
---@field appId string 客户端ID
---@field userName string 用户名。只能包含英文或数字，长度为5-20位，首位不能为数字。
---@field password string 密码。长度为5到20位之间。
---@field email string 备用邮箱（找回密码用）。长度不能超过50个字符。
---@field screenName string 昵称。长度不能超过50个字符。
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌，不参与旧版Hash计算。

---@class DandanAPIResetPasswordResponseV2 : DandanAPIResponseBase

---@class DandanAPIResetPasswordRequestV2
---@field appId string 应用ID
---@field userName string 用户名
---@field email string 注册此用户时填写的备用邮箱
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌，不参与旧版Hash计算。

---@class DandanAPIFindMyIdResponse : DandanAPIResponseBase

---@class DandanAPIFindMyIdRequestV2
---@field appId string 应用ID
---@field email string 注册此用户时填写的备用邮箱
---@field unixTimestamp? int Unix时间戳：从协调世界时1970年1月1日0时0分0秒起至现在的总秒数，不考虑闰秒。
---@field hash string 通过参数计算得到的32位MD5值，不区分大小写。计算方法请参考接口说明。
---@field captchaToken? string 风险触发时的人机验证令牌，不参与旧版Hash计算。

---@class DandanAPISearchAnimeResponse : DandanAPIResponseBase
---@field animes? DandanAPISearchAnimeDetails[] 作品列表

---@class DandanAPISearchAnimeDetails
---@field animeId int 作品ID
---@field bangumiId? string 作品ID（新）
---@field animeTitle? string 作品标题
---@field type DandanAPIAnimeType 作品类型
---@field typeDescription? string 类型描述
---@field imageUrl? string 海报图片地址
---@field startDate? string 上映日期
---@field episodeCount int 剧集总数
---@field rating number 此作品的综合评分（0-10）
---@field isFavorited boolean 当前用户是否已关注此作品

---@class DandanAPISearchEpisodesResponse : DandanAPIResponseBase
---@field hasMore boolean 是否有更多未显示的搜索结果。当返回的搜索结果过多时此值为`true`
---@field animes? DandanAPISearchEpisodesAnime[] 搜索结果（作品信息）列表

---@class DandanAPISearchEpisodesAnime
---@field animeId int 作品编号
---@field animeTitle? string 作品标题
---@field type DandanAPIAnimeType 作品类型
---@field typeDescription? string 类型描述
---@field episodes? DandanAPISearchEpisodeDetails[] 此作品的剧集列表

---@class DandanAPISearchEpisodeDetails
---@field episodeId int 剧集ID（弹幕库编号）
---@field episodeTitle? string 剧集标题

---@class DandanAPISearchBangumiResponse : DandanAPIResponseBase
---@field bangumis? DandanAPISearchBangumiDetails[] 搜索结果

---@class DandanAPISearchBangumiDetails : DandanAPISearchAnimeDetails
---@field rank int 搜索结果中的排名，用于界面中排序展示，从1开始递增
---@field searchKeyword? string 搜索关键词
---@field isOnAir boolean 是否正在连载中
---@field isRestricted boolean 是否为限制级别的内容（例如属于R18分级）
---@field intro? string 短简介（剧情简介或Staff简介）

---@class DandanAPISearchAdvancedConfigResponse : DandanAPIResponseBase
---@field types? DandanAPIConfigKey[] 类型列表
---@field tags? DandanAPIConfigKey[] 可用标签列表
---@field sorts? DandanAPIConfigKey[] 排序依据
---@field minYear int 搜索允许的最早年份
---@field maxYear int 搜索允许的最晚年份

---@class DandanAPIConfigKey
---@field key int 搜索中使用的值
---@field value? string 用户界面上显示的文字

---@class DandanAPITrendingBangumiResponse : DandanAPIResponseBase
---@field summary? DandanAPITrendingSummary 榜单元数据
---@field bangumiList? DandanAPITrendingBangumiItem[] 榜单条目

---@class DandanAPITrendingSummary
---@field title? string 榜单标题
---@field rankingType? string 榜单类型。hot=热播榜，rising=飙升榜，new-anime-hot=新番热播榜
---@field period? string 统计周期。week=周，month=月，quarter=季度，season=季度新番，year=年度新番
---@field scope? string 榜单范围。all=全站，current-season=本季新番，previous-season=上一季度新番，current-year=今年新番
---@field dateFrom? string 当前统计开始日期（服务器时区）
---@field dateTo? string 当前统计结束日期（服务器时区）
---@field compareDateFrom? string 对比统计开始日期（仅飙升榜有效）
---@field compareDateTo? string 对比统计结束日期（仅飙升榜有效）
---@field latestDataDate? string 当前可用的最新完整数据日期

---@class DandanAPITrendingBangumiItem : DandanAPIBangumiIntro
---@field rank int 当前排名
---@field heat? string 当前统计周期内的脱敏热度值
---@field activeDays int 当前周期内有热度的天数
---@field previousHeat? string 对比周期脱敏热度值（仅飙升榜有效）
---@field heatDelta? string 当前周期与对比周期的脱敏热度差值（仅飙升榜有效）
---@field heatGrowthRate? string 热度增长率文本（仅飙升榜有效）

---@class DandanAPIUserProfileResponse : DandanAPIResponseBase
---@field userId int 弹弹play用户编号。
---@field userName? string 弹弹play用户名。
---@field email? string 当前账号邮箱。
---@field userType? string 用户注册来源类型。
---@field screenName? string 用户昵称。
---@field profileImage? string 当前用户头像 URL。
---@field emailVerified boolean 是否已完成邮箱验证。
---@field accountTier? string 当前账号额度层级，例如 Unverified 或 Verified。
---@field payConfigs? DandanAPIPayConfig[] 当前可用的支付渠道和商品配置。
---@field privileges? DandanAPIUserPrivileges 当前用户权益到期时间。
---@field linkedAccounts? DandanAPILinkedAccounts 已关联的第三方账号。

---@class DandanAPIUserUpdateProfileResponseV2 : DandanAPIResponseBase
---@field updateScreenName? string
---@field updateProfileImage? string

---@class DandanAPIUserUpdatePasswordRequest
---@field oldPassword string 旧密码（5-20位）
---@field newPassword string 新密码（5-20位）

---@class DandanAPIUserUpdateProfileRequest
---@field screenName? string 用户新的昵称（留空将不修改昵称）
---@field profileImageBase64? string 用户头像图片使用Base64编码后的数据（jpg格式，长度不能超过1MB）。留空将不修改头像图片

---@class DandanAPIUserUpdateEmailRequest
---@field oldEmail string 当前的关联邮箱地址
---@field newEmail string 新的关联邮箱地址

return M
