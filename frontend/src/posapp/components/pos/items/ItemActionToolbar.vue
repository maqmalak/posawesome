<template>
	<v-card
		class="cards mb-0 mt-3 dynamic-padding"
		:class="{ 'cards--with-mobile-offset': reserveBottomDockSpace }"
	>
		<v-row no-gutters align="center" justify="center" class="dynamic-spacing-sm">
			<v-col cols="12" class="mb-2">
				<nav class="group-crumbs" :aria-label="__('Items Group')">
					<template v-for="(group, index) in itemsGroup" :key="group">
						<v-icon v-if="index > 0" size="16" class="group-crumbs__sep">mdi-chevron-right</v-icon>
						<button
							type="button"
							class="group-crumbs__item"
							:class="{ 'group-crumbs__item--active': group === (modelValue || 'ALL') }"
							:style="{ '--crumb-color': groupStyle(group).color }"
							:aria-current="group === (modelValue || 'ALL') ? 'page' : undefined"
							@click="$emit('update:modelValue', group)"
						>
							<span class="group-crumbs__icon" aria-hidden="true">
								<v-icon size="15">{{ groupStyle(group).icon }}</v-icon>
							</span>
							{{ group === "ALL" ? __("All") : group }}
						</button>
					</template>
				</nav>
			</v-col>
			<v-col cols="12" class="mb-2" v-if="posProfile.posa_enable_price_list_dropdown !== false">
				<v-text-field
					density="compact"
					variant="solo"
					color="primary"
					:label="frappe._('Price List')"
					hide-details
					:model-value="activePriceList"
					readonly
				></v-text-field>
			</v-col>
			<v-col cols="12" sm="4" class="dynamic-margin-xs">
				<v-btn-toggle
					:model-value="itemsView"
					@update:model-value="$emit('update:itemsView', $event)"
					color="primary"
					group
					density="compact"
					rounded
					class="view-toggle-btn"
				>
					<v-btn size="small" value="list">{{ __("List") }}</v-btn>
					<v-btn size="small" value="card">{{ __("Card") }}</v-btn>
				</v-btn-toggle>
			</v-col>
			<v-col cols="6" sm="4" class="dynamic-margin-xs">
				<v-btn
					size="small"
					block
					color="warning"
					variant="text"
					@click="$emit('open-offers')"
					class="action-btn-consistent"
				>
					{{ offersCount }} {{ __("Offers") }}
				</v-btn>
			</v-col>
			<v-col cols="6" sm="4" class="dynamic-margin-xs">
				<v-btn
					size="small"
					block
					color="primary"
					variant="text"
					@click="$emit('open-coupons')"
					class="action-btn-consistent"
				>
					{{ couponsCount }} {{ __("Coupons") }}
				</v-btn>
			</v-col>
		</v-row>
	</v-card>
</template>

<script setup>
const __ = window.__;

defineProps({
	modelValue: { type: String, default: "ALL" }, // item_group
	itemsGroup: { type: Array, default: () => [] },
	itemsView: { type: String, default: "card" },
	posProfile: { type: Object, required: true },
	activePriceList: { type: String, default: "" },
	offersCount: { type: Number, default: 0 },
	couponsCount: { type: Number, default: 0 },
	reserveBottomDockSpace: { type: Boolean, default: false },
});

defineEmits(["update:modelValue", "update:itemsView", "open-offers", "open-coupons"]);

const KEYWORD_STYLES = [
	{ match: /food|meal|dish|snack|burger|pizza/i, icon: "mdi-silverware-fork-knife", color: "#ea580c" },
	{ match: /bever|drink|juice|coffee|tea/i, icon: "mdi-cup", color: "#0d9488" },
	{ match: /add[\s-]?on|extra|side|topping/i, icon: "mdi-plus-circle-outline", color: "#d97706" },
	{ match: /dessert|sweet|cake|bakery/i, icon: "mdi-cupcake", color: "#db2777" },
	{ match: /fruit|veg|fresh/i, icon: "mdi-food-apple-outline", color: "#16a34a" },
];
const FALLBACK_ICONS = ["mdi-tag-outline", "mdi-shape-outline", "mdi-package-variant", "mdi-star-outline"];
const FALLBACK_COLORS = ["#4f46e5", "#0891b2", "#9333ea", "#be123c", "#65a30d", "#c2410c"];

// Stable per-name pick so a group keeps the same look across sessions.
const hashName = (name) => [...name].reduce((h, ch) => (h * 31 + ch.charCodeAt(0)) >>> 0, 7);

const groupStyle = (group) => {
	if (group === "ALL") return { icon: "mdi-view-grid-outline", color: "#475569" };
	const known = KEYWORD_STYLES.find((s) => s.match.test(group));
	if (known) return known;
	const h = hashName(group);
	return {
		icon: FALLBACK_ICONS[h % FALLBACK_ICONS.length],
		color: FALLBACK_COLORS[h % FALLBACK_COLORS.length],
	};
};
</script>

<style scoped>
.action-btn-consistent {
	height: 36px !important;
	margin-top: var(--dynamic-xs) !important;
	padding: var(--pos-space-2) var(--pos-space-3) !important;
	transition: var(--transition-normal) !important;
	border-radius: var(--pos-radius-sm) !important;
	text-transform: none !important;
	font-weight: 600 !important;
}

.action-btn-consistent:hover {
	background-color: rgba(var(--v-theme-primary), 0.1) !important;
	transform: none !important;
}

.group-crumbs {
	display: flex;
	align-items: center;
	gap: 2px;
	min-height: 40px;
	padding: 4px 6px;
	overflow-x: auto;
	scrollbar-width: thin;
	white-space: nowrap;
	background: var(--pos-input-bg, rgb(var(--v-theme-surface)));
	border: 1px solid var(--pos-border-light);
	border-radius: var(--pos-radius-sm);
}

.group-crumbs__item {
	display: inline-flex;
	align-items: center;
	gap: 6px;
	flex-shrink: 0;
	padding: 3px 12px 3px 4px;
	border: 1px solid transparent;
	border-radius: 999px;
	font-size: 0.875rem;
	font-weight: 500;
	color: var(--pos-text-secondary, rgba(var(--v-theme-on-surface), 0.72));
	transition: var(--transition-normal);
}

.group-crumbs__icon {
	display: inline-flex;
	align-items: center;
	justify-content: center;
	width: 26px;
	height: 26px;
	border-radius: 50%;
	color: var(--crumb-color);
	background-color: color-mix(in srgb, var(--crumb-color) 15%, transparent);
	transition: var(--transition-normal);
}

.group-crumbs__item:hover {
	color: var(--crumb-color);
	background-color: color-mix(in srgb, var(--crumb-color) 8%, transparent);
}

.group-crumbs__item:focus-visible {
	outline: 2px solid var(--crumb-color);
	outline-offset: 1px;
}

.group-crumbs__item--active {
	color: var(--crumb-color);
	border-color: color-mix(in srgb, var(--crumb-color) 35%, transparent);
	background-color: color-mix(in srgb, var(--crumb-color) 12%, transparent);
	font-weight: 700;
}

.group-crumbs__item--active .group-crumbs__icon {
	color: #ffffff;
	background-color: var(--crumb-color);
}

.group-crumbs__sep {
	flex-shrink: 0;
	opacity: 0.45;
}

.view-toggle-btn {
	height: 36px;
	border: 1px solid var(--pos-border-light);
	border-radius: var(--pos-radius-sm);
}

.dynamic-padding {
	padding: var(--dynamic-sm);
}

.dynamic-spacing-sm {
	padding: var(--dynamic-sm) !important;
}

.cards {
	background-color: var(--pos-surface-muted) !important;
	margin-top: var(--dynamic-sm) !important;
	padding: var(--dynamic-sm) !important;
	border: 1px solid var(--pos-border-light);
	border-radius: var(--pos-radius-md) !important;
	box-shadow: none !important;
	position: sticky;
	bottom: 0;
	z-index: 7;
	min-width: 0;
	overflow: visible;
}

.cards--with-mobile-offset {
	margin-bottom: calc(var(--bottom-safe-space) + 6px) !important;
}

@media (max-width: 1099px) {
	.cards {
		position: static;
	}
}

@media (max-width: 768px) {
	.dynamic-padding {
		padding: var(--dynamic-xs);
	}

	.dynamic-spacing-sm {
		padding: var(--dynamic-xs) !important;
	}

	.view-toggle-btn {
		width: 100%;
	}

	.action-btn-consistent {
		padding: var(--dynamic-xs) !important;
		font-size: 0.875rem !important;
		min-height: 42px !important;
	}
}

@media (max-width: 480px) {
	.cards {
		padding: var(--dynamic-xs) !important;
		position: static;
	}
}
</style>
