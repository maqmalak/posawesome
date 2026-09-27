/**
 * Utility functions for responsive item card layout.
 */

/**
 * Calculates the number of columns based on container width.
 */
export const getCardColumns = (width: number): number => {
    if (width <= 768) {
        return 1;
    }
    if (width <= 1200) {
        return 2;
    }
    return 3;
};

export const MIN_CARD_WIDTH = 150;
export const MAX_CARD_COLUMNS = 5;

/**
 * Fits as many cards of at least MIN_CARD_WIDTH as the measured container
 * allows, capped at MAX_CARD_COLUMNS.
 */
export const getCardColumnsForContainer = (
    containerWidth: number,
    gap: number,
    padding: number,
): number => {
    const usable = containerWidth - padding * 2 + gap;
    const columns = Math.floor(usable / (MIN_CARD_WIDTH + gap));
    return Math.min(MAX_CARD_COLUMNS, Math.max(1, columns));
};

/**
 * Calculates the gap between cards based on container width.
 */
export const getCardGap = (width: number): number => {
    if (width <= 768) {
        return 10;
    }
    if (width <= 1200) {
        return 12;
    }
    return 16;
};

/**
 * Calculates the padding for the card container based on container width.
 */
export const getCardPadding = (width: number): number => {
    if (width <= 768) {
        return 10;
    }
    if (width <= 1200) {
        return 12;
    }
    return 16;
};
