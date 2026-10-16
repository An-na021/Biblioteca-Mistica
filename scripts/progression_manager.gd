class_name ProgressionManager
extends RefCounted

const DAILY_SALES_TARGET := 3
const DAILY_SALES_REWARD := 6
const DAILY_CLEAN_REWARD := 4
const WEEKLY_SALES_TARGET := 12
const WEEKLY_PROFIT_TARGET := 100
const WEEKLY_REWARD := 25

const ACHIEVEMENTS := {
	"five_perfect": {"title": "Atendimento impecável", "description": "Atenda cinco clientes seguidos sem erro."},
	"ten_purchases": {"title": "Olho de livreiro", "description": "Compre dez exemplares de fornecedores."},
	"three_suppliers": {"title": "Rede de contatos", "description": "Compre de três fornecedores diferentes."},
	"three_districts": {"title": "Conhecedor da cidade", "description": "Visite os três bairros da cidade."},
	"reputation_5": {"title": "Nome respeitado", "description": "Alcance cinco pontos de reputação."}
}

var daily_sales := 0
var daily_errors := 0
var daily_profit := 0
var weekly_sales := 0
var weekly_profit := 0
var weekly_errors := 0
var current_week := -1
var sales_without_error := 0
var total_purchases := 0
var suppliers_used: Dictionary = {}
var districts_visited: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var pending_achievements: Array[Dictionary] = []
var weekly_reward_claimed := false
var daily_customer_target := DAILY_SALES_TARGET


func begin_day(day_number: int, customer_target: int) -> void:
	var week_number := int(floor(float(day_number - 1) / 7.0))
	if week_number != current_week:
		current_week = week_number
		weekly_sales = 0
		weekly_profit = 0
		weekly_errors = 0
		weekly_reward_claimed = false
	daily_sales = 0
	daily_errors = 0
	daily_profit = 0
	daily_customer_target = mini(DAILY_SALES_TARGET, customer_target)


func record_sale(profit: int) -> void:
	daily_sales += 1
	daily_profit += profit
	weekly_sales += 1
	weekly_profit += profit
	sales_without_error += 1
	if sales_without_error >= 5:
		_unlock("five_perfect")


func record_error() -> void:
	daily_errors += 1
	weekly_errors += 1
	sales_without_error = 0


func record_purchase(supplier_id: String) -> void:
	total_purchases += 1
	suppliers_used[supplier_id] = true
	if total_purchases >= 10:
		_unlock("ten_purchases")
	if suppliers_used.size() >= 3:
		_unlock("three_suppliers")


func record_district_visit(district_id: String) -> void:
	districts_visited[district_id] = true
	if districts_visited.size() >= 3:
		_unlock("three_districts")


func record_reputation(value: int) -> void:
	if value >= 5:
		_unlock("reputation_5")


func _unlock(achievement_id: String) -> void:
	if unlocked_achievements.has(achievement_id) or not ACHIEVEMENTS.has(achievement_id):
		return
	var achievement: Dictionary = ACHIEVEMENTS[achievement_id].duplicate(true)
	achievement["id"] = achievement_id
	unlocked_achievements[achievement_id] = true
	pending_achievements.append(achievement)


func take_new_achievements() -> Array[Dictionary]:
	var result := pending_achievements.duplicate(true)
	pending_achievements.clear()
	return result

func get_unlocked_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for achievement_id in unlocked_achievements:
		var achievement: Dictionary = ACHIEVEMENTS[achievement_id].duplicate(true)
		achievement["id"] = achievement_id
		result.append(achievement)
	return result


func finish_day() -> Dictionary:
	var daily_goals: Array[Dictionary] = [
		_goal("sales", "Conclua %d vendas" % daily_customer_target, daily_sales, daily_customer_target, DAILY_SALES_REWARD),
		_goal("clean_day", "Feche o dia sem erros", 1 if daily_errors == 0 else 0, 1, DAILY_CLEAN_REWARD)
	]
	var reward := 0
	var daily_reward := 0
	for goal in daily_goals:
		if bool(goal["completed"]):
			daily_reward += int(goal["reward"])
	reward += daily_reward
	var weekly_goals: Array[Dictionary] = [
		_goal("weekly_sales", "Venda %d livros na semana" % WEEKLY_SALES_TARGET, weekly_sales, WEEKLY_SALES_TARGET, 0),
		_goal("weekly_profit", "Lucre %d moedas na semana" % WEEKLY_PROFIT_TARGET, weekly_profit, WEEKLY_PROFIT_TARGET, 0)
	]
	var weekly_complete := true
	for goal in weekly_goals:
		weekly_complete = weekly_complete and bool(goal["completed"])
	var weekly_reward := 0
	if weekly_complete and not weekly_reward_claimed:
		weekly_reward = WEEKLY_REWARD
		reward += weekly_reward
		weekly_reward_claimed = true
	return {
		"daily_goals": daily_goals,
		"weekly_goals": weekly_goals,
		"daily_reward": daily_reward,
		"weekly_reward": weekly_reward,
		"weekly_reward_available": 0 if weekly_reward_claimed else WEEKLY_REWARD,
		"weekly_reward_claimed": weekly_reward_claimed,
		"reward": reward,
		"week_number": current_week + 1,
		"achievement_count": unlocked_achievements.size(),
		"achievements": take_new_achievements(),
		"unlocked_achievements": get_unlocked_achievements()
	}


func _goal(goal_id: String, title: String, progress: int, target: int, reward: int) -> Dictionary:
	return {
		"id": goal_id,
		"title": title,
		"progress": mini(progress, target),
		"target": target,
		"reward": reward,
		"completed": progress >= target
	}
