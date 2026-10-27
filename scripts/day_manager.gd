class_name DayManager
extends RefCounted

signal customer_ready(index: int, total: int)
signal store_closed

const MIN_CUSTOMERS := 3
const MAX_CUSTOMERS := 5
const MIN_WAIT_SECONDS := 3.0
const MAX_WAIT_SECONDS := 6.0
const END_OF_DAY_NOTICE_SECONDS := 5.0

var day := 1
var customers_today := 0
var served_today := 0
var waiting_seconds := 0.0
var waiting_for_next := false
var waiting_for_end_notice := false
var store_is_open := false

func start_day(customer_limit := MAX_CUSTOMERS) -> void:
	var maximum_customers := clampi(customer_limit, 1, MAX_CUSTOMERS)
	customers_today = randi_range(mini(MIN_CUSTOMERS, maximum_customers), maximum_customers)
	served_today = 0
	waiting_for_next = false
	waiting_for_end_notice = false
	store_is_open = true
	customer_ready.emit(1, customers_today)

func customer_completed() -> void:
	served_today += 1
	if served_today >= customers_today:
		waiting_for_end_notice = true
		waiting_seconds = END_OF_DAY_NOTICE_SECONDS
		return
	waiting_seconds = randf_range(MIN_WAIT_SECONDS, MAX_WAIT_SECONDS)
	waiting_for_next = true

func tick(delta: float) -> void:
	if waiting_for_end_notice:
		waiting_seconds -= delta
		if waiting_seconds <= 0.0:
			waiting_for_end_notice = false
			store_is_open = false
			store_closed.emit()
		return
	if not waiting_for_next:
		return
	waiting_seconds -= delta
	if waiting_seconds <= 0.0:
		waiting_for_next = false
		if store_is_open:
			customer_ready.emit(served_today + 1, customers_today)

func close_store() -> void:
	store_is_open = false
	waiting_for_next = false
	waiting_for_end_notice = false

func finish_day(customer_limit := MAX_CUSTOMERS) -> void:
	day += 1
	start_day(customer_limit)
