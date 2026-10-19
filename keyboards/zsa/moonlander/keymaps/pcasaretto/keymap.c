#include QMK_KEYBOARD_H
#include "version.h"
#include "i18n.h"
#define MOON_LED_LEVEL LED_LEVEL
#ifndef ZSA_SAFE_RANGE
#define ZSA_SAFE_RANGE SAFE_RANGE
#endif

enum custom_keycodes {
  RGB_SLD = ZSA_SAFE_RANGE,
  ST_MACRO_0,
  ST_MACRO_1,
  ST_MACRO_2,
  ST_MACRO_3,
  ST_MACRO_4,
  ST_MACRO_5,
  ST_MACRO_6,
};



enum tap_dance_codes {
  DANCE_0,
  DANCE_1,
  DANCE_2,
  DANCE_3,
};


const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [0] = LAYOUT_moonlander(
    KC_GRAVE,       KC_1,           KC_2,           KC_3,           KC_4,           KC_5,           KC_MINUS,                                       KC_EQUAL,       KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           LALT(KC_SPACE), 
    KC_TAB,         KC_Q,           KC_W,           KC_E,           KC_R,           KC_T,           KC_LBRC,                                        KC_RBRC,        KC_Y,           KC_U,           KC_I,           KC_O,           KC_P,           KC_BSLS,        
    KC_LEFT_CTRL,   KC_A,           KC_S,           KC_D,           KC_F,           KC_G,           KC_LPRN,                                                                        KC_RPRN,        KC_H,           KC_J,           KC_K,           KC_L,           KC_SCLN,        KC_QUOTE,       
    KC_LEFT_SHIFT,  KC_Z,           KC_X,           KC_C,           KC_V,           KC_B,                                           KC_N,           MT(MOD_RCTL, KC_M),KC_COMMA,       KC_DOT,         KC_SLASH,       KC_RIGHT_SHIFT, 
    KC_ESCAPE,      KC_TRANSPARENT, KC_TRANSPARENT, KC_LEFT_ALT,    CW_TOGG,        TD(DANCE_0),                                                                                                    LT(4, KC_MEDIA_PLAY_PAUSE),TD(DANCE_1),    KC_LEFT,        KC_DOWN,        KC_UP,          KC_RIGHT,       
    KC_SPACE,       KC_LEFT_GUI,    MO(1),                          TT(2),          MT(MOD_RSFT, KC_ENTER),KC_BSPC
  ),
  [1] = LAYOUT_moonlander(
    TO(0),          KC_TRANSPARENT, TO(2),          TO(3),          TO(4),          TO(5),          KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, RALT(KC_UP),    KC_TRANSPARENT, KC_TRANSPARENT, KC_TAB,         
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, LGUI(LSFT(KC_LBRC)),KC_TRANSPARENT, LGUI(LSFT(KC_RBRC)),KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_LEFT_GUI,    KC_LEFT_ALT,    KC_LEFT_SHIFT,  KC_TRANSPARENT, KC_TRANSPARENT,                                                                 KC_TRANSPARENT, KC_LEFT,        KC_DOWN,        KC_UP,          KC_RIGHT,       KC_NO,          KC_BSPC,        
    KC_TRANSPARENT, KC_MAC_UNDO,    KC_MAC_CUT,     KC_MAC_COPY,    KC_MAC_PASTE,   KC_TRANSPARENT,                                 KC_TRANSPARENT, RGUI(KC_D),     RALT(KC_DOWN),  RGUI(KC_ENTER), KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [2] = LAYOUT_moonlander(
    TO(0),          LALT(KC_LBRC),  TD(DANCE_2),    KC_LABK,        KC_RABK,        TD(DANCE_3),    LALT(LSFT(KC_LBRC)),                                KC_LPRN,        KC_RPRN,        KC_KP_SLASH,    KC_KP_ASTERISK, KC_KP_MINUS,    KC_KP_PLUS,     KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_LCBR,        KC_RCBR,        KC_PLUS,        KC_EQUAL,                                       KC_EXLM,        KC_CIRC,        KC_KP_7,        KC_KP_8,        KC_KP_9,        KC_KP_PLUS,     KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_QUOTE,       KC_DQUO,        KC_LPRN,        KC_RPRN,        KC_MINUS,       KC_UNDS,                                                                        KC_DLR,         KC_PERC,        KC_KP_4,        KC_KP_5,        KC_KP_6,        KC_EQUAL,       KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, LALT(KC_SCLN),  KC_LBRC,        KC_RBRC,        LALT(KC_8),                                     KC_KP_COMMA,    KC_KP_1,        KC_KP_2,        KC_KP_3,        KC_EQUAL,       KC_TRANSPARENT, 
    LGUI(LCTL(KC_SPACE)),KC_TRANSPARENT, KC_TRANSPARENT, LALT(KC_MINUS), LALT(LSFT(KC_MINUS)),KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_KP_PLUS,     KC_KP_0,        KC_KP_DOT,      KC_KP_ENTER,    KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, TO(0),                          KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [3] = LAYOUT_moonlander(
    TO(0),          KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, LGUI(LSFT(KC_4)),LGUI(LCTL(KC_SPACE)),KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, ST_MACRO_0,     ST_MACRO_1,     KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, ST_MACRO_5,     KC_TRANSPARENT, KC_TRANSPARENT, ST_MACRO_6,     KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, ST_MACRO_2,     KC_TRANSPARENT, ST_MACRO_3,     KC_TRANSPARENT, KC_TRANSPARENT,                                                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, ST_MACRO_4,     KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, TO(0),                          TO(0),          KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [4] = LAYOUT_moonlander(
    TO(0),          KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_AUDIO_MUTE,  KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, LGUI(LCTL(KC_Q)),
    KC_TRANSPARENT, KC_MS_WH_UP,    KC_MS_BTN2,     KC_MS_UP,       KC_MS_BTN1,     KC_MS_WH_DOWN,  KC_PAGE_UP,                                     KC_AUDIO_VOL_UP,KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_MS_WH_DOWN,  KC_MS_LEFT,     KC_MS_DOWN,     KC_MS_RIGHT,    KC_MS_WH_UP,    KC_PGDN,                                                                        KC_AUDIO_VOL_DOWN,KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, RGB_MODE_FORWARD,RGB_TOG,        KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_TRANSPARENT, KC_TRANSPARENT, RGB_HUD,        RGB_VAD,        RGB_VAI,        RGB_HUI,        
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_MEDIA_PLAY_PAUSE,KC_MEDIA_PREV_TRACK,KC_BRIGHTNESS_DOWN,KC_BRIGHTNESS_UP,KC_MEDIA_NEXT_TRACK,
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                 KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [5] = LAYOUT_moonlander(
    TO(0),          KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, AU_TOGG,                                        KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, TO(6),          MU_TOGG,                                        KC_TRANSPARENT, KC_DLR,         RSFT(KC_C),     RSFT(KC_D),     RSFT(KC_E),     RSFT(KC_F),     KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, MU_NEXT,                                                                        KC_TRANSPARENT, KC_HASH,        KC_8,           KC_9,           RSFT(KC_A),     RSFT(KC_B),     KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                 KC_X,           KC_4,           KC_5,           KC_6,           KC_7,           KC_TRANSPARENT, 
    QK_BOOT,        KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT, KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_0,           KC_1,           KC_2,           KC_3,           KC_TRANSPARENT, 
    KC_TRANSPARENT, KC_TRANSPARENT, TO(0),                          TO(0),          KC_TRANSPARENT, KC_TRANSPARENT
  ),
  [6] = LAYOUT_moonlander(
    KC_H,           KC_U,           KC_J,           KC_A,           KC_W,           KC_S,           KC_E,                                           KC_D,           KC_F,           KC_T,           KC_G,           KC_Y,           KC_H,           KC_U,           
    KC_D,           KC_F,           KC_T,           KC_G,           KC_Y,           KC_H,           KC_U,                                           KC_J,           KC_A,           KC_W,           KC_S,           KC_E,           KC_D,           KC_F,           
    KC_J,           KC_A,           KC_W,           KC_S,           KC_E,           KC_D,           KC_F,                                                                           KC_T,           KC_G,           KC_Y,           KC_H,           KC_U,           KC_J,           KC_A,           
    KC_T,           KC_G,           KC_Y,           KC_H,           KC_U,           KC_J,                                           KC_S,           KC_E,           KC_D,           KC_F,           KC_T,           KC_G,           
    KC_W,           KC_S,           KC_E,           KC_D,           KC_F,           KC_TRANSPARENT,                                                                                                 KC_TRANSPARENT, KC_U,           KC_J,           KC_A,           KC_W,           KC_S,           
    KC_Z,           KC_C,           TO(0),                          KC_TRANSPARENT, KC_V,           KC_X
  ),
};





extern rgb_config_t rgb_matrix_config;

RGB hsv_to_rgb_with_value(HSV hsv) {
  RGB rgb = hsv_to_rgb( hsv );
  float f = (float)rgb_matrix_config.hsv.v / UINT8_MAX;
  return (RGB){ f * rgb.r, f * rgb.g, f * rgb.b };
}

void keyboard_post_init_user(void) {
  rgb_matrix_enable();
}

const uint8_t PROGMEM ledmap[][RGB_MATRIX_LED_COUNT][3] = {
    [0] = { {14,255,255}, {105,255,255}, {105,255,255}, {105,255,255}, {0,0,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {0,0,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {0,0,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {105,255,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {138,65,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {14,255,255}, {14,255,255}, {14,255,255}, {0,0,255}, {105,255,255}, {0,0,255}, {138,65,255}, {35,218,204}, {14,255,255}, {14,255,255}, {105,255,255}, {0,0,255}, {14,255,255}, {0,0,255}, {14,255,255}, {14,255,255}, {0,0,255}, {14,255,255}, {0,0,255}, {0,0,255}, {14,255,255}, {0,0,255}, {14,255,255}, {0,0,255}, {0,0,255}, {14,255,255}, {0,0,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {138,65,255}, {14,255,255}, {0,0,255}, {0,0,255}, {0,0,255}, {14,255,255}, {14,255,255}, {14,255,255}, {0,0,255}, {138,65,255}, {0,0,255}, {138,65,255} },

    [1] = { {249,228,255}, {0,0,0}, {14,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {105,255,255}, {0,0,0}, {249,228,255}, {0,0,0}, {154,255,255}, {105,255,255}, {0,0,0}, {249,228,255}, {0,0,0}, {154,255,255}, {105,255,255}, {0,0,0}, {249,228,255}, {0,0,0}, {154,255,255}, {105,255,255}, {0,0,0}, {249,228,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {14,255,255}, {0,0,0}, {14,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {105,255,255}, {35,255,255}, {0,0,0}, {154,255,255}, {105,255,255}, {105,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {154,255,255}, {105,255,255}, {35,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {249,228,255}, {0,0,0} },

    [2] = { {249,228,255}, {0,0,0}, {0,0,0}, {0,0,0}, {35,255,255}, {14,255,255}, {0,0,0}, {35,255,255}, {0,0,0}, {0,0,0}, {14,255,255}, {0,0,0}, {35,255,255}, {14,255,255}, {0,0,0}, {154,255,255}, {154,255,255}, {154,255,255}, {154,255,255}, {14,255,255}, {154,255,255}, {154,255,255}, {154,255,255}, {154,255,255}, {14,255,255}, {14,255,255}, {105,255,255}, {105,255,255}, {14,255,255}, {14,255,255}, {105,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {154,255,255}, {154,255,255}, {154,255,255}, {154,255,255}, {154,255,255}, {105,255,255}, {105,255,255}, {105,255,255}, {154,255,255}, {154,255,255}, {105,255,255}, {105,255,255}, {105,255,255}, {105,255,255}, {154,255,255}, {105,255,255}, {105,255,255}, {105,255,255}, {154,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} },

    [3] = { {249,228,255}, {0,0,0}, {0,0,0}, {0,0,0}, {14,255,255}, {0,0,0}, {0,0,0}, {105,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {154,255,255}, {105,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {35,255,255}, {0,0,0}, {0,0,0}, {0,0,255}, {14,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {105,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {35,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {249,228,255}, {0,0,0}, {0,0,0}, {105,255,255}, {0,0,0}, {35,255,255}, {0,0,0}, {0,0,0}, {105,255,255}, {154,255,255}, {0,0,0}, {105,255,255}, {0,0,0}, {105,255,255}, {0,0,0}, {0,0,0}, {14,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} },

    [4] = { {249,228,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {35,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {105,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {35,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {14,255,255}, {14,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {249,228,255}, {0,0,0}, {0,0,0}, {154,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {14,255,255}, {35,255,255}, {35,255,255}, {0,0,0}, {0,0,0}, {14,255,255}, {35,255,255}, {35,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {154,255,255}, {105,255,255}, {105,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} },

    [5] = { {249,228,255}, {0,0,0}, {0,0,0}, {0,0,0}, {249,228,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {14,255,255}, {0,0,0}, {105,255,255}, {0,0,0}, {0,0,0}, {154,255,255}, {154,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {0,0,0}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {0,0,0}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {0,0,0}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {0,0,0}, {14,255,255}, {14,255,255}, {14,255,255}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} },

    [6] = { {35,255,255}, {35,255,255}, {31,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {14,255,255}, {14,255,255}, {35,255,255}, {105,255,255}, {154,255,255}, {0,0,0}, {0,0,0}, {14,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {14,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {35,255,255}, {14,255,255}, {105,255,255}, {154,255,255}, {0,0,0}, {0,0,0} },

};

void set_layer_color(int layer) {
  for (int i = 0; i < RGB_MATRIX_LED_COUNT; i++) {
    HSV hsv = {
      .h = pgm_read_byte(&ledmap[layer][i][0]),
      .s = pgm_read_byte(&ledmap[layer][i][1]),
      .v = pgm_read_byte(&ledmap[layer][i][2]),
    };
    if (!hsv.h && !hsv.s && !hsv.v) {
        rgb_matrix_set_color( i, 0, 0, 0 );
    } else {
        RGB rgb = hsv_to_rgb_with_value(hsv);
        rgb_matrix_set_color(i, rgb.r, rgb.g, rgb.b);
    }
  }
}

bool rgb_matrix_indicators_user(void) {
  if (rawhid_state.rgb_control) {
      return false;
  }
  if (!keyboard_config.disable_layer_led) { 
    switch (biton32(layer_state)) {
      case 0:
        set_layer_color(0);
        break;
      case 1:
        set_layer_color(1);
        break;
      case 2:
        set_layer_color(2);
        break;
      case 3:
        set_layer_color(3);
        break;
      case 4:
        set_layer_color(4);
        break;
      case 5:
        set_layer_color(5);
        break;
      case 6:
        set_layer_color(6);
        break;
     default:
        if (rgb_matrix_get_flags() == LED_FLAG_NONE) {
          rgb_matrix_set_color_all(0, 0, 0);
        }
    }
  } else {
    if (rgb_matrix_get_flags() == LED_FLAG_NONE) {
      rgb_matrix_set_color_all(0, 0, 0);
    }
  }

  return true;
}


typedef struct {
    bool is_press_action;
    uint8_t step;
} tap;

enum {
    SINGLE_TAP = 1,      
    SINGLE_HOLD,         
    DOUBLE_TAP,          
    DOUBLE_HOLD,         
    DOUBLE_SINGLE_TAP,   
    MORE_TAPS            
};

static tap dance_state[4];

uint8_t dance_step(tap_dance_state_t *state);

uint8_t dance_step(tap_dance_state_t *state) {
    if (state->count == 1) {
        if (state->interrupted || !state->pressed) return SINGLE_TAP;
        else return SINGLE_HOLD;
    } else if (state->count == 2) {
        if (state->interrupted) return DOUBLE_SINGLE_TAP;
        else if (state->pressed) return DOUBLE_HOLD;
        else return DOUBLE_TAP;
    }
    return MORE_TAPS;
}


void on_dance_0(tap_dance_state_t *state, void *user_data);
void dance_0_finished(tap_dance_state_t *state, void *user_data);
void dance_0_reset(tap_dance_state_t *state, void *user_data);

void on_dance_0(tap_dance_state_t *state, void *user_data) {
    if(state->count == 3) {
        tap_code16(LGUI(KC_SPACE));
        tap_code16(LGUI(KC_SPACE));
        tap_code16(LGUI(KC_SPACE));
    }
    if(state->count > 3) {
        tap_code16(LGUI(KC_SPACE));
    }
}

void dance_0_finished(tap_dance_state_t *state, void *user_data) {
    dance_state[0].step = dance_step(state);
    switch (dance_state[0].step) {
        case SINGLE_TAP: register_code16(LGUI(KC_SPACE)); break;
        case SINGLE_HOLD: layer_on(3); break;
        case DOUBLE_TAP: register_code16(LGUI(KC_TAB)); break;
        case DOUBLE_SINGLE_TAP: tap_code16(LGUI(KC_SPACE)); register_code16(LGUI(KC_SPACE));
    }
}

void dance_0_reset(tap_dance_state_t *state, void *user_data) {
    wait_ms(10);
    switch (dance_state[0].step) {
        case SINGLE_TAP: unregister_code16(LGUI(KC_SPACE)); break;
        case SINGLE_HOLD:
          layer_off(3);
        break;
        case DOUBLE_TAP: unregister_code16(LGUI(KC_TAB)); break;
        case DOUBLE_SINGLE_TAP: unregister_code16(LGUI(KC_SPACE)); break;
    }
    dance_state[0].step = 0;
}
void dance_1_finished(tap_dance_state_t *state, void *user_data);
void dance_1_reset(tap_dance_state_t *state, void *user_data);

void dance_1_finished(tap_dance_state_t *state, void *user_data) {
    dance_state[1].step = dance_step(state);
    switch (dance_state[1].step) {
        case SINGLE_HOLD: register_code16(KC_RIGHT_ALT); break;
        case DOUBLE_TAP: layer_move(2); break;
    }
}

void dance_1_reset(tap_dance_state_t *state, void *user_data) {
    wait_ms(10);
    switch (dance_state[1].step) {
        case SINGLE_HOLD: unregister_code16(KC_RIGHT_ALT); break;
    }
    dance_state[1].step = 0;
}
void on_dance_2(tap_dance_state_t *state, void *user_data);
void dance_2_finished(tap_dance_state_t *state, void *user_data);
void dance_2_reset(tap_dance_state_t *state, void *user_data);

void on_dance_2(tap_dance_state_t *state, void *user_data) {
    if(state->count == 3) {
        tap_code16(LALT(KC_RBRC));
        tap_code16(LALT(KC_RBRC));
        tap_code16(LALT(KC_RBRC));
    }
    if(state->count > 3) {
        tap_code16(LALT(KC_RBRC));
    }
}

void dance_2_finished(tap_dance_state_t *state, void *user_data) {
    dance_state[2].step = dance_step(state);
    switch (dance_state[2].step) {
        case SINGLE_TAP: register_code16(LALT(KC_RBRC)); break;
        case DOUBLE_TAP: register_code16(LALT(KC_LBRC)); break;
        case DOUBLE_SINGLE_TAP: tap_code16(LALT(KC_RBRC)); register_code16(LALT(KC_RBRC));
    }
}

void dance_2_reset(tap_dance_state_t *state, void *user_data) {
    wait_ms(10);
    switch (dance_state[2].step) {
        case SINGLE_TAP: unregister_code16(LALT(KC_RBRC)); break;
        case DOUBLE_TAP: unregister_code16(LALT(KC_LBRC)); break;
        case DOUBLE_SINGLE_TAP: unregister_code16(LALT(KC_RBRC)); break;
    }
    dance_state[2].step = 0;
}
void on_dance_3(tap_dance_state_t *state, void *user_data);
void dance_3_finished(tap_dance_state_t *state, void *user_data);
void dance_3_reset(tap_dance_state_t *state, void *user_data);

void on_dance_3(tap_dance_state_t *state, void *user_data) {
    if(state->count == 3) {
        tap_code16(LALT(LSFT(KC_RBRC)));
        tap_code16(LALT(LSFT(KC_RBRC)));
        tap_code16(LALT(LSFT(KC_RBRC)));
    }
    if(state->count > 3) {
        tap_code16(LALT(LSFT(KC_RBRC)));
    }
}

void dance_3_finished(tap_dance_state_t *state, void *user_data) {
    dance_state[3].step = dance_step(state);
    switch (dance_state[3].step) {
        case SINGLE_TAP: register_code16(LALT(LSFT(KC_RBRC))); break;
        case DOUBLE_TAP: register_code16(LALT(LSFT(KC_LBRC))); break;
        case DOUBLE_SINGLE_TAP: tap_code16(LALT(LSFT(KC_RBRC))); register_code16(LALT(LSFT(KC_RBRC)));
    }
}

void dance_3_reset(tap_dance_state_t *state, void *user_data) {
    wait_ms(10);
    switch (dance_state[3].step) {
        case SINGLE_TAP: unregister_code16(LALT(LSFT(KC_RBRC))); break;
        case DOUBLE_TAP: unregister_code16(LALT(LSFT(KC_LBRC))); break;
        case DOUBLE_SINGLE_TAP: unregister_code16(LALT(LSFT(KC_RBRC))); break;
    }
    dance_state[3].step = 0;
}

tap_dance_action_t tap_dance_actions[] = {
        [DANCE_0] = ACTION_TAP_DANCE_FN_ADVANCED(on_dance_0, dance_0_finished, dance_0_reset),
        [DANCE_1] = ACTION_TAP_DANCE_FN_ADVANCED(NULL, dance_1_finished, dance_1_reset),
        [DANCE_2] = ACTION_TAP_DANCE_FN_ADVANCED(on_dance_2, dance_2_finished, dance_2_reset),
        [DANCE_3] = ACTION_TAP_DANCE_FN_ADVANCED(on_dance_3, dance_3_finished, dance_3_reset),
};

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  switch (keycode) {
  case QK_MODS ... QK_MODS_MAX:
    // Mouse and consumer keys (volume, media) with modifiers work inconsistently across operating systems,
    // this makes sure that modifiers are always applied to the key that was pressed.
    if (IS_MOUSE_KEYCODE(QK_MODS_GET_BASIC_KEYCODE(keycode)) || IS_CONSUMER_KEYCODE(QK_MODS_GET_BASIC_KEYCODE(keycode))) {
      if (record->event.pressed) {
        add_mods(QK_MODS_GET_MODS(keycode));
        send_keyboard_report();
        wait_ms(2);
        register_code(QK_MODS_GET_BASIC_KEYCODE(keycode));
        return false;
      } else {
        wait_ms(2);
        del_mods(QK_MODS_GET_MODS(keycode));
      }
    }
    break;
    case ST_MACRO_0:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_LSFT(SS_TAP(X_R))SS_DELAY(100)  SS_TAP(X_A)SS_DELAY(100)  SS_TAP(X_C)SS_DELAY(100)  SS_TAP(X_K)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;
    case ST_MACRO_1:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_TAP(X_I)SS_DELAY(100)  SS_LSFT(SS_TAP(X_K))SS_DELAY(100)  SS_TAP(X_I)SS_DELAY(100)  SS_TAP(X_T)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;
    case ST_MACRO_2:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_LSFT(SS_TAP(X_S))SS_DELAY(100)  SS_TAP(X_P)SS_DELAY(100)  SS_TAP(X_O)SS_DELAY(100)  SS_TAP(X_T)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;
    case ST_MACRO_3:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_TAP(X_C)SS_DELAY(100)  SS_TAP(X_H)SS_DELAY(100)  SS_TAP(X_R)SS_DELAY(100)  SS_TAP(X_O)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;
    case ST_MACRO_4:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_LSFT(SS_TAP(X_S))SS_DELAY(100)  SS_TAP(X_L)SS_DELAY(100)  SS_TAP(X_A)SS_DELAY(100)  SS_TAP(X_C)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;
    case ST_MACRO_5:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_TAP(X_Z)SS_DELAY(100)  SS_TAP(X_O)SS_DELAY(100)  SS_TAP(X_O)SS_DELAY(100)  SS_TAP(X_M)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;
    case ST_MACRO_6:
    if (record->event.pressed) {
      SEND_STRING(SS_LGUI(SS_TAP(X_SPACE))SS_DELAY(100)  SS_LSFT(SS_TAP(X_P))SS_DELAY(100)  SS_TAP(X_R)SS_DELAY(100)  SS_TAP(X_E)SS_DELAY(100)  SS_TAP(X_F)  SS_DELAY(100) SS_TAP(X_ENTER));
    }
    break;

    case RGB_SLD:
        if (rawhid_state.rgb_control) {
            return false;
        }
        if (record->event.pressed) {
            rgblight_mode(1);
        }
        return false;
  }
  return true;
}

