## ============================================================
## GoogleBilling.gd - Google Play内购封装
## ============================================================
## 作用: 封装Google Play Billing API，实现安卓内购。
## 设计: Node（需监听信号），由PlatformAdapter实例化并add_child。
## 依赖: GodotGooglePlayBilling插件 (addons/google_play_billing/)
## 对应: I4.03 谷歌支付
## 流程: connect → querySkuDetails → launchBillingFlow → onPurchasesUpdated
## ============================================================

extends Node

## BillingClient单例引用（插件提供）
var _billing: Object = null

## 是否已连接Google Play
var _connected: bool = false

## 商品详情缓存（sku → 详情Dictionary）
var _sku_details: Dictionary = {}

## 待处理的购买回调（querySkuDetails返回后触发）
var _pending_purchase_callback: Callable = Callable()


func _ready() -> void:
	# 获取GodotGooglePlayBilling单例
	_billing = Engine.get_singleton("GodotGooglePlayBilling")
	if _billing != null:
		# 连接信号
		_billing.connected.connect(_on_connected)
		_billing.disconnected.connect(_on_disconnected)
		_billing.sku_details_query_completed.connect(_on_sku_details)
		_billing.purchases_updated.connect(_on_purchases_updated)
		# 启动连接
		_billing.startConnection()
		print("[GoogleBilling] 正在连接Google Play...")
	else:
		print("[GoogleBilling] 插件未安装，内购不可用")


## ============================================================
## 连接管理
## ============================================================

func _on_connected() -> void:
	_connected = true
	print("[GoogleBilling] 已连接Google Play")


func _on_disconnected() -> void:
	_connected = false
	print("[GoogleBilling] 已断开Google Play")


## ============================================================
## 商品查询
## ============================================================

## 查询商品详情
## [param sku_list] 商品ID数组
func query_sku_details(sku_list: PackedStringArray) -> void:
	if not _connected or _billing == null:
		print("[GoogleBilling] 未连接，无法查询商品")
		return
	_billing.querySkuDetails(sku_list, "inapp")  ## inapp=一次性消费, subs=订阅


func _on_sku_details(sku_details_list: Array) -> void:
	for details in sku_details_list:
		var sku: String = details.get("sku", "")
		_sku_details[sku] = details
	print("[GoogleBilling] 已查询到 %d 个商品" % sku_details_list.size())


## ============================================================
## 发起购买
## ============================================================

## 发起购买
## [param product_id] 商品ID（SKU）
## [param callback] 结果回调: func(success: bool) -> void
func purchase(product_id: String, callback: Callable) -> void:
	if not _connected or _billing == null:
		print("[GoogleBilling] 未连接，无法购买: ", product_id)
		if callback.is_valid():
			callback.call(false)
		return
	_pending_purchase_callback = callback
	# 发起购买流程
	_billing.launchBillingFlow(product_id, "inapp")
	print("[GoogleBilling] 发起购买: ", product_id)


## 购买结果回调
func _on_purchases_updated(purchases: Array) -> void:
	if purchases.is_empty():
		print("[GoogleBilling] 购买取消")
		if _pending_purchase_callback.is_valid():
			_pending_purchase_callback.call(false)
			_pending_purchase_callback = Callable()
		return
	# 检查购买状态
	var purchase = purchases[0]
	var state: int = purchase.get("purchase_state", 0)
	# 4 = PURCHASED (已购买)
	if state == 4:
		print("[GoogleBilling] 购买成功")
		# TODO: 服务器验证收据后再发放商品
		if _pending_purchase_callback.is_valid():
			_pending_purchase_callback.call(true)
	else:
		print("[GoogleBilling] 购买状态: ", state)
		if _pending_purchase_callback.is_valid():
			_pending_purchase_callback.call(false)
	_pending_purchase_callback = Callable()


## ============================================================
## 消耗商品
## ============================================================

## 消耗已购商品（消耗型商品需调用）
## [param purchase_token] 购买令牌
func consume_purchase(purchase_token: String) -> void:
	if _billing == null:
		return
	_billing.consumePurchase(purchase_token)
