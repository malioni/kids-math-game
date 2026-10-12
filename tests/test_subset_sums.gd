extends GutTest


func test_subset_sums_counts_single_answer() -> void:
	assert_eq(SubsetSums.analyze([2, 3, 7], 5)["count"], 1)


func test_subset_sums_equal_values_count_once() -> void:
	assert_eq(SubsetSums.analyze([2, 2, 3, 3], 5)["count"], 1)


func test_subset_sums_no_answer_has_zero_sizes() -> void:
	assert_eq(SubsetSums.analyze([4, 6, 8], 5), {"count": 0, "min_size": 0, "max_size": 0})


func test_subset_sums_reports_fewest_and_most_values_used() -> void:
	# 6 = 6, 1+5, 1+2+3
	var stats: Dictionary = SubsetSums.analyze([1, 2, 3, 5, 6], 6)
	assert_eq(stats["count"], 3)
	assert_eq(stats["min_size"], 1)
	assert_eq(stats["max_size"], 3)


func test_subset_sums_empty_values_has_no_answer() -> void:
	var values: Array[int] = []
	assert_eq(SubsetSums.analyze(values, 3)["count"], 0)
