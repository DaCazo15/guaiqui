export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      ad_daily_progress: {
        Row: {
          blocks_paid: number
          completed_count: number
          created_at: string
          day: string
          updated_at: string
          user_id: string
        }
        Insert: {
          blocks_paid?: number
          completed_count?: number
          created_at?: string
          day: string
          updated_at?: string
          user_id: string
        }
        Update: {
          blocks_paid?: number
          completed_count?: number
          created_at?: string
          day?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ad_daily_progress_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ad_reconciliation: {
        Row: {
          day: string
          google_rewarded_impressions: number
          imported_at: string
          imported_by: string | null
          notes: string | null
        }
        Insert: {
          day: string
          google_rewarded_impressions?: number
          imported_at?: string
          imported_by?: string | null
          notes?: string | null
        }
        Update: {
          day?: string
          google_rewarded_impressions?: number
          imported_at?: string
          imported_by?: string | null
          notes?: string | null
        }
        Relationships: []
      }
      ad_reward_tiers: {
        Row: {
          block_number: number
          pearls: number
          updated_at: string
        }
        Insert: {
          block_number: number
          pearls: number
          updated_at?: string
        }
        Update: {
          block_number?: number
          pearls?: number
          updated_at?: string
        }
        Relationships: []
      }
      ad_sessions: {
        Row: {
          block_index: number | null
          completed_at: string | null
          created_at: string
          day: string
          id: string
          reason: string | null
          started_at: string
          status: string
          user_id: string
        }
        Insert: {
          block_index?: number | null
          completed_at?: string | null
          created_at?: string
          day: string
          id?: string
          reason?: string | null
          started_at?: string
          status: string
          user_id: string
        }
        Update: {
          block_index?: number | null
          completed_at?: string | null
          created_at?: string
          day?: string
          id?: string
          reason?: string | null
          started_at?: string
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ad_sessions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      app_secrets: {
        Row: {
          created_at: string
          key_name: string
          secret_value: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          key_name: string
          secret_value: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          key_name?: string
          secret_value?: string
          updated_at?: string
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          after: Json | null
          before: Json | null
          created_at: string
          entity: string
          entity_id: string | null
          id: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          entity: string
          entity_id?: string | null
          id?: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          entity?: string
          entity_id?: string | null
          id?: string
        }
        Relationships: []
      }
      auth_trigger_errors: {
        Row: {
          created_at: string
          error_message: string
          id: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          error_message: string
          id?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          error_message?: string
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      birthday_settings: {
        Row: {
          bonus_pearls: number
          enabled: boolean
          grace_days: number
          id: number
          image_url: string | null
          message: string
          send_hour: number
          title: string
          updated_at: string
        }
        Insert: {
          bonus_pearls?: number
          enabled?: boolean
          grace_days?: number
          id?: number
          image_url?: string | null
          message?: string
          send_hour?: number
          title?: string
          updated_at?: string
        }
        Update: {
          bonus_pearls?: number
          enabled?: boolean
          grace_days?: number
          id?: number
          image_url?: string | null
          message?: string
          send_hour?: number
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      blocked_identities: {
        Row: {
          created_at: string
          email_hmac: string
          id: string
          reason: string
        }
        Insert: {
          created_at?: string
          email_hmac: string
          id?: string
          reason: string
        }
        Update: {
          created_at?: string
          email_hmac?: string
          id?: string
          reason?: string
        }
        Relationships: []
      }
      captcha_passes: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          ip_hash: string
          used: boolean
          user_id: string
        }
        Insert: {
          created_at?: string
          expires_at: string
          id?: string
          ip_hash: string
          used?: boolean
          user_id: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          ip_hash?: string
          used?: boolean
          user_id?: string
        }
        Relationships: []
      }
      carousel_slides: {
        Row: {
          badge_variant: string | null
          bg_gradient: string | null
          created_at: string
          cta_text: string | null
          cta_url: string | null
          ends_at: string | null
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          starts_at: string
          subtitle: string | null
          tag: string | null
          title: string
        }
        Insert: {
          badge_variant?: string | null
          bg_gradient?: string | null
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          ends_at?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          starts_at?: string
          subtitle?: string | null
          tag?: string | null
          title: string
        }
        Update: {
          badge_variant?: string | null
          bg_gradient?: string | null
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          ends_at?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          starts_at?: string
          subtitle?: string | null
          tag?: string | null
          title?: string
        }
        Relationships: []
      }
      display_name_change_logs: {
        Row: {
          changed_at: string
          id: string
          new_name: string
          old_name: string | null
          user_id: string
        }
        Insert: {
          changed_at?: string
          id?: string
          new_name: string
          old_name?: string | null
          user_id: string
        }
        Update: {
          changed_at?: string
          id?: string
          new_name?: string
          old_name?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "display_name_change_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      economy_settings: {
        Row: {
          ad_min_account_age_days: number
          ad_min_seconds: number
          ad_min_trivias_completed: number
          ads_enabled: boolean
          block_size: number
          created_at: string
          daily_ad_views: number
          daily_pearl_cap: number
          id: string
          streak_bonus_config: Json
          weekly_pearl_cap: number
        }
        Insert: {
          ad_min_account_age_days?: number
          ad_min_seconds?: number
          ad_min_trivias_completed?: number
          ads_enabled?: boolean
          block_size?: number
          created_at?: string
          daily_ad_views?: number
          daily_pearl_cap?: number
          id?: string
          streak_bonus_config?: Json
          weekly_pearl_cap?: number
        }
        Update: {
          ad_min_account_age_days?: number
          ad_min_seconds?: number
          ad_min_trivias_completed?: number
          ads_enabled?: boolean
          block_size?: number
          created_at?: string
          daily_ad_views?: number
          daily_pearl_cap?: number
          id?: string
          streak_bonus_config?: Json
          weekly_pearl_cap?: number
        }
        Relationships: []
      }
      email_usage_tracker: {
        Row: {
          active_key_index: number
          created_at: string
          limit_reached_alert_sent: boolean
          period_yyyy_mm: string
          total_sent: number
          updated_at: string
        }
        Insert: {
          active_key_index?: number
          created_at?: string
          limit_reached_alert_sent?: boolean
          period_yyyy_mm: string
          total_sent?: number
          updated_at?: string
        }
        Update: {
          active_key_index?: number
          created_at?: string
          limit_reached_alert_sent?: boolean
          period_yyyy_mm?: string
          total_sent?: number
          updated_at?: string
        }
        Relationships: []
      }
      faqs: {
        Row: {
          answer: string
          created_at: string
          id: string
          is_published: boolean
          order_index: number
          question: string
        }
        Insert: {
          answer: string
          created_at?: string
          id?: string
          is_published?: boolean
          order_index?: number
          question: string
        }
        Update: {
          answer?: string
          created_at?: string
          id?: string
          is_published?: boolean
          order_index?: number
          question?: string
        }
        Relationships: []
      }
      fraud_telemetry: {
        Row: {
          action: string
          created_at: string
          device_id: string | null
          fan_id: string
          id: string
          ip_hash: string | null
        }
        Insert: {
          action: string
          created_at?: string
          device_id?: string | null
          fan_id: string
          id?: string
          ip_hash?: string | null
        }
        Update: {
          action?: string
          created_at?: string
          device_id?: string | null
          fan_id?: string
          id?: string
          ip_hash?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fraud_telemetry_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      games: {
        Row: {
          created_at: string
          game_date: string
          id: string
          is_home: boolean
          location: string
          opponent: string
          opponent_score: number | null
          our_score: number | null
          status: Database["public"]["Enums"]["game_status"]
        }
        Insert: {
          created_at?: string
          game_date: string
          id?: string
          is_home?: boolean
          location?: string
          opponent: string
          opponent_score?: number | null
          our_score?: number | null
          status?: Database["public"]["Enums"]["game_status"]
        }
        Update: {
          created_at?: string
          game_date?: string
          id?: string
          is_home?: boolean
          location?: string
          opponent?: string
          opponent_score?: number | null
          our_score?: number | null
          status?: Database["public"]["Enums"]["game_status"]
        }
        Relationships: []
      }
      hall_of_fame_championships: {
        Row: {
          created_at: string
          highlight: string | null
          id: string
          is_hexa: boolean
          is_published: boolean
          order_index: number
          runner_up: string | null
          tournament: string
          year: number
        }
        Insert: {
          created_at?: string
          highlight?: string | null
          id?: string
          is_hexa?: boolean
          is_published?: boolean
          order_index?: number
          runner_up?: string | null
          tournament: string
          year: number
        }
        Update: {
          created_at?: string
          highlight?: string | null
          id?: string
          is_hexa?: boolean
          is_published?: boolean
          order_index?: number
          runner_up?: string | null
          tournament?: string
          year?: number
        }
        Relationships: []
      }
      hall_of_fame_jerseys: {
        Row: {
          badge_icon: string
          created_at: string
          description: string | null
          highlight: string | null
          id: string
          is_published: boolean
          jersey_number: number
          nickname: string | null
          order_index: number
          player_name: string
          position: string | null
          titles_badge: string | null
          titles_count: number
          years_active: string | null
        }
        Insert: {
          badge_icon?: string
          created_at?: string
          description?: string | null
          highlight?: string | null
          id?: string
          is_published?: boolean
          jersey_number: number
          nickname?: string | null
          order_index?: number
          player_name: string
          position?: string | null
          titles_badge?: string | null
          titles_count?: number
          years_active?: string | null
        }
        Update: {
          badge_icon?: string
          created_at?: string
          description?: string | null
          highlight?: string | null
          id?: string
          is_published?: boolean
          jersey_number?: number
          nickname?: string | null
          order_index?: number
          player_name?: string
          position?: string | null
          titles_badge?: string | null
          titles_count?: number
          years_active?: string | null
        }
        Relationships: []
      }
      hall_of_fame_legends: {
        Row: {
          achievements: string[]
          bio: string | null
          category: string
          created_at: string
          era: string | null
          id: string
          image_url: string | null
          is_published: boolean
          name: string
          nickname: string | null
          order_index: number
          position: string | null
          role: string
          titles: string[]
        }
        Insert: {
          achievements?: string[]
          bio?: string | null
          category?: string
          created_at?: string
          era?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          name: string
          nickname?: string | null
          order_index?: number
          position?: string | null
          role?: string
          titles?: string[]
        }
        Update: {
          achievements?: string[]
          bio?: string | null
          category?: string
          created_at?: string
          era?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          name?: string
          nickname?: string | null
          order_index?: number
          position?: string | null
          role?: string
          titles?: string[]
        }
        Relationships: []
      }
      hero_carousel_slides: {
        Row: {
          created_at: string
          cta_text: string | null
          cta_url: string | null
          guarantee_1: string | null
          guarantee_2: string | null
          guarantee_3: string | null
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          show_guarantees: boolean
          subtitle: string | null
          tag: string | null
          text_align: string
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          guarantee_1?: string | null
          guarantee_2?: string | null
          guarantee_3?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          show_guarantees?: boolean
          subtitle?: string | null
          tag?: string | null
          text_align?: string
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          cta_text?: string | null
          cta_url?: string | null
          guarantee_1?: string | null
          guarantee_2?: string | null
          guarantee_3?: string | null
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          show_guarantees?: boolean
          subtitle?: string | null
          tag?: string | null
          text_align?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      history_milestones: {
        Row: {
          created_at: string
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          text: string
          title: string
          year: string
        }
        Insert: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          text: string
          title: string
          year: string
        }
        Update: {
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          text?: string
          title?: string
          year?: string
        }
        Relationships: []
      }
      instagram_posts: {
        Row: {
          caption: string | null
          created_at: string
          id: string
          image_url: string | null
          is_published: boolean
          order_index: number
          post_url: string
          shortcode: string | null
        }
        Insert: {
          caption?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          post_url: string
          shortcode?: string | null
        }
        Update: {
          caption?: string | null
          created_at?: string
          id?: string
          image_url?: string | null
          is_published?: boolean
          order_index?: number
          post_url?: string
          shortcode?: string | null
        }
        Relationships: []
      }
      landing_ctas: {
        Row: {
          badge_text: string | null
          bg_color: string | null
          bg_gradient: string | null
          button_text: string | null
          button_url: string | null
          created_at: string
          font_family: string | null
          font_size: string | null
          font_weight: string | null
          heading: string | null
          id: string
          is_active: boolean
          is_published: boolean
          letter_spacing: string | null
          media_type: string | null
          media_value: string | null
          name: string
          phrase_text: string | null
          placement: string
          subtitle: string | null
          text_color: string | null
          type: string
          updated_at: string
        }
        Insert: {
          badge_text?: string | null
          bg_color?: string | null
          bg_gradient?: string | null
          button_text?: string | null
          button_url?: string | null
          created_at?: string
          font_family?: string | null
          font_size?: string | null
          font_weight?: string | null
          heading?: string | null
          id?: string
          is_active?: boolean
          is_published?: boolean
          letter_spacing?: string | null
          media_type?: string | null
          media_value?: string | null
          name: string
          phrase_text?: string | null
          placement?: string
          subtitle?: string | null
          text_color?: string | null
          type?: string
          updated_at?: string
        }
        Update: {
          badge_text?: string | null
          bg_color?: string | null
          bg_gradient?: string | null
          button_text?: string | null
          button_url?: string | null
          created_at?: string
          font_family?: string | null
          font_size?: string | null
          font_weight?: string | null
          heading?: string | null
          id?: string
          is_active?: boolean
          is_published?: boolean
          letter_spacing?: string | null
          media_type?: string | null
          media_value?: string | null
          name?: string
          phrase_text?: string | null
          placement?: string
          subtitle?: string | null
          text_color?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: []
      }
      landing_settings: {
        Row: {
          cta_primary_text: string
          cta_primary_url: string
          cta_secondary_text: string
          cta_secondary_url: string
          dark_mode_enabled: boolean
          footer_brand_description: string | null
          footer_copyright: string | null
          footer_disclaimer: string | null
          footer_location: string | null
          footer_support_hours: string | null
          footer_support_text: string | null
          footer_support_url: string | null
          hero_badge_text: string | null
          hero_card_color: string | null
          hero_carousel_enabled: boolean
          hero_guarantee_1: string | null
          hero_guarantee_2: string | null
          hero_guarantee_3: string | null
          hero_image_url: string | null
          hero_subtitle: string
          hero_title: string
          id: number
          theme_color: string
          updated_at: string
        }
        Insert: {
          cta_primary_text?: string
          cta_primary_url?: string
          cta_secondary_text?: string
          cta_secondary_url?: string
          dark_mode_enabled?: boolean
          footer_brand_description?: string | null
          footer_copyright?: string | null
          footer_disclaimer?: string | null
          footer_location?: string | null
          footer_support_hours?: string | null
          footer_support_text?: string | null
          footer_support_url?: string | null
          hero_badge_text?: string | null
          hero_card_color?: string | null
          hero_carousel_enabled?: boolean
          hero_guarantee_1?: string | null
          hero_guarantee_2?: string | null
          hero_guarantee_3?: string | null
          hero_image_url?: string | null
          hero_subtitle?: string
          hero_title?: string
          id?: number
          theme_color?: string
          updated_at?: string
        }
        Update: {
          cta_primary_text?: string
          cta_primary_url?: string
          cta_secondary_text?: string
          cta_secondary_url?: string
          dark_mode_enabled?: boolean
          footer_brand_description?: string | null
          footer_copyright?: string | null
          footer_disclaimer?: string | null
          footer_location?: string | null
          footer_support_hours?: string | null
          footer_support_text?: string | null
          footer_support_url?: string | null
          hero_badge_text?: string | null
          hero_card_color?: string | null
          hero_carousel_enabled?: boolean
          hero_guarantee_1?: string | null
          hero_guarantee_2?: string | null
          hero_guarantee_3?: string | null
          hero_image_url?: string | null
          hero_subtitle?: string
          hero_title?: string
          id?: number
          theme_color?: string
          updated_at?: string
        }
        Relationships: []
      }
      ledger_entries: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          fan_id: string
          id: string
          note: string | null
          source_id: string
          source_type: string
          status: Database["public"]["Enums"]["ledger_status"]
          type: Database["public"]["Enums"]["ledger_type"]
        }
        Insert: {
          amount: number
          created_at?: string
          created_by?: string | null
          fan_id: string
          id?: string
          note?: string | null
          source_id: string
          source_type: string
          status?: Database["public"]["Enums"]["ledger_status"]
          type: Database["public"]["Enums"]["ledger_type"]
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          fan_id?: string
          id?: string
          note?: string | null
          source_id?: string
          source_type?: string
          status?: Database["public"]["Enums"]["ledger_status"]
          type?: Database["public"]["Enums"]["ledger_type"]
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ledger_hold_resolutions: {
        Row: {
          action: string
          created_at: string
          id: string
          ledger_id: string
          note: string
          resolved_by: string
        }
        Insert: {
          action: string
          created_at?: string
          id?: string
          ledger_id: string
          note: string
          resolved_by: string
        }
        Update: {
          action?: string
          created_at?: string
          id?: string
          ledger_id?: string
          note?: string
          resolved_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "ledger_hold_resolutions_ledger_id_fkey"
            columns: ["ledger_id"]
            isOneToOne: true
            referencedRelation: "ledger_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_hold_resolutions_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      login_modal_slides: {
        Row: {
          created_at: string
          created_by: string | null
          cta_label: string
          cta_url: string
          ends_at: string | null
          id: string
          image_url: string | null
          position: number
          starts_at: string
          status: string
          subtitle: string | null
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          cta_label?: string
          cta_url: string
          ends_at?: string | null
          id?: string
          image_url?: string | null
          position: number
          starts_at?: string
          status?: string
          subtitle?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          cta_label?: string
          cta_url?: string
          ends_at?: string | null
          id?: string
          image_url?: string | null
          position?: number
          starts_at?: string
          status?: string
          subtitle?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      mfa_recovery_codes: {
        Row: {
          code_hash: string
          created_at: string
          id: string
          used_at: string | null
          user_id: string
        }
        Insert: {
          code_hash: string
          created_at?: string
          id?: string
          used_at?: string | null
          user_id: string
        }
        Update: {
          code_hash?: string
          created_at?: string
          id?: string
          used_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      notification_outbox: {
        Row: {
          attempts: number
          channel: string
          created_at: string
          error: string | null
          id: string
          next_attempt_at: string
          notification_id: string
          sent_at: string | null
          status: string
        }
        Insert: {
          attempts?: number
          channel: string
          created_at?: string
          error?: string | null
          id?: string
          next_attempt_at?: string
          notification_id: string
          sent_at?: string | null
          status?: string
        }
        Update: {
          attempts?: number
          channel?: string
          created_at?: string
          error?: string | null
          id?: string
          next_attempt_at?: string
          notification_id?: string
          sent_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_outbox_notification_id_fkey"
            columns: ["notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          data: Json | null
          dedup_key: string
          id: string
          read_at: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          data?: Json | null
          dedup_key: string
          id?: string
          read_at?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          data?: Json | null
          dedup_key?: string
          id?: string
          read_at?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      players: {
        Row: {
          age: number | null
          bio: string | null
          created_at: string
          height: string | null
          id: string
          instagram_url: string | null
          is_active: boolean
          is_star: boolean
          jersey_number: number
          name: string
          nationality: string | null
          position: string
        }
        Insert: {
          age?: number | null
          bio?: string | null
          created_at?: string
          height?: string | null
          id?: string
          instagram_url?: string | null
          is_active?: boolean
          is_star?: boolean
          jersey_number: number
          name: string
          nationality?: string | null
          position: string
        }
        Update: {
          age?: number | null
          bio?: string | null
          created_at?: string
          height?: string | null
          id?: string
          instagram_url?: string | null
          is_active?: boolean
          is_star?: boolean
          jersey_number?: number
          name?: string
          nationality?: string | null
          position?: string
        }
        Relationships: []
      }
      policy_documents: {
        Row: {
          content_markdown: string
          created_at: string
          id: string
          is_active: boolean
          published_at: string
          slug: string
          updated_at: string | null
          version: string
        }
        Insert: {
          content_markdown: string
          created_at?: string
          id?: string
          is_active?: boolean
          published_at?: string
          slug: string
          updated_at?: string | null
          version: string
        }
        Update: {
          content_markdown?: string
          created_at?: string
          id?: string
          is_active?: boolean
          published_at?: string
          slug?: string
          updated_at?: string | null
          version?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          active: boolean
          category: Database["public"]["Enums"]["product_category"]
          cost_pearls: number
          created_at: string
          description: string | null
          id: string
          images: string[] | null
          name: string
          stock: number
          valid_from: string
          valid_until: string | null
          variants: Json | null
        }
        Insert: {
          active?: boolean
          category?: Database["public"]["Enums"]["product_category"]
          cost_pearls: number
          created_at?: string
          description?: string | null
          id?: string
          images?: string[] | null
          name: string
          stock?: number
          valid_from?: string
          valid_until?: string | null
          variants?: Json | null
        }
        Update: {
          active?: boolean
          category?: Database["public"]["Enums"]["product_category"]
          cost_pearls?: number
          created_at?: string
          description?: string | null
          id?: string
          images?: string[] | null
          name?: string
          stock?: number
          valid_from?: string
          valid_until?: string | null
          variants?: Json | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          birth_date: string | null
          cover_url: string | null
          created_at: string
          deleted_at: string | null
          display_name: string
          favorite_player_id: string | null
          gender: string | null
          id: string
          last_birth_date_change: string | null
          municipality: string | null
          notification_prefs: Json | null
          pearls_rules_accepted_at: string | null
          pearls_rules_version: string | null
          privacy_accepted_at: string | null
          privacy_version: string | null
          referral_source: string | null
          shirt_size: string | null
          status: Database["public"]["Enums"]["user_status"]
          terms_accepted_at: string | null
          terms_version: string | null
        }
        Insert: {
          avatar_url?: string | null
          birth_date?: string | null
          cover_url?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name: string
          favorite_player_id?: string | null
          gender?: string | null
          id: string
          last_birth_date_change?: string | null
          municipality?: string | null
          notification_prefs?: Json | null
          pearls_rules_accepted_at?: string | null
          pearls_rules_version?: string | null
          privacy_accepted_at?: string | null
          privacy_version?: string | null
          referral_source?: string | null
          shirt_size?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          terms_accepted_at?: string | null
          terms_version?: string | null
        }
        Update: {
          avatar_url?: string | null
          birth_date?: string | null
          cover_url?: string | null
          created_at?: string
          deleted_at?: string | null
          display_name?: string
          favorite_player_id?: string | null
          gender?: string | null
          id?: string
          last_birth_date_change?: string | null
          municipality?: string | null
          notification_prefs?: Json | null
          pearls_rules_accepted_at?: string | null
          pearls_rules_version?: string | null
          privacy_accepted_at?: string | null
          privacy_version?: string | null
          referral_source?: string | null
          shirt_size?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          terms_accepted_at?: string | null
          terms_version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_favorite_player"
            columns: ["favorite_player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
        ]
      }
      push_subscriptions: {
        Row: {
          auth: string
          created_at: string
          disabled_at: string | null
          endpoint: string
          id: string
          last_success_at: string | null
          p256dh: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          auth: string
          created_at?: string
          disabled_at?: string | null
          endpoint: string
          id?: string
          last_success_at?: string | null
          p256dh: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          auth?: string
          created_at?: string
          disabled_at?: string | null
          endpoint?: string
          id?: string
          last_success_at?: string | null
          p256dh?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "push_subscriptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      rate_limits: {
        Row: {
          action: string
          request_count: number
          user_id: string
          window_start: string
        }
        Insert: {
          action: string
          request_count?: number
          user_id: string
          window_start: string
        }
        Update: {
          action?: string
          request_count?: number
          user_id?: string
          window_start?: string
        }
        Relationships: []
      }
      redemption_history: {
        Row: {
          changed_by: string | null
          created_at: string
          id: string
          new_status: Database["public"]["Enums"]["redemption_status"]
          note: string | null
          previous_status:
            | Database["public"]["Enums"]["redemption_status"]
            | null
          redemption_id: string
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          id?: string
          new_status: Database["public"]["Enums"]["redemption_status"]
          note?: string | null
          previous_status?:
            | Database["public"]["Enums"]["redemption_status"]
            | null
          redemption_id: string
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          id?: string
          new_status?: Database["public"]["Enums"]["redemption_status"]
          note?: string | null
          previous_status?:
            | Database["public"]["Enums"]["redemption_status"]
            | null
          redemption_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "redemption_history_redemption_id_fkey"
            columns: ["redemption_id"]
            isOneToOne: false
            referencedRelation: "redemptions"
            referencedColumns: ["id"]
          },
        ]
      }
      redemptions: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          code_hash: string
          cost_pearls: number
          created_at: string
          delivered_at: string | null
          delivered_by: string | null
          delivery_idempotency_key: string | null
          expires_at: string | null
          fan_id: string
          id: string
          idempotency_key: string
          product_id: string
          qr_key_id: string | null
          status: Database["public"]["Enums"]["redemption_status"]
          variant: string | null
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          code_hash: string
          cost_pearls: number
          created_at?: string
          delivered_at?: string | null
          delivered_by?: string | null
          delivery_idempotency_key?: string | null
          expires_at?: string | null
          fan_id: string
          id?: string
          idempotency_key: string
          product_id: string
          qr_key_id?: string | null
          status?: Database["public"]["Enums"]["redemption_status"]
          variant?: string | null
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          code_hash?: string
          cost_pearls?: number
          created_at?: string
          delivered_at?: string | null
          delivered_by?: string | null
          delivery_idempotency_key?: string | null
          expires_at?: string | null
          fan_id?: string
          id?: string
          idempotency_key?: string
          product_id?: string
          qr_key_id?: string | null
          status?: Database["public"]["Enums"]["redemption_status"]
          variant?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "redemptions_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "staff_members"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "redemptions_delivered_by_fkey"
            columns: ["delivered_by"]
            isOneToOne: false
            referencedRelation: "staff_members"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "redemptions_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "redemptions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      risk_flags: {
        Row: {
          created_at: string
          fan_id: string
          id: string
          reason: string
          resolved: boolean
          severity: Database["public"]["Enums"]["risk_severity"]
        }
        Insert: {
          created_at?: string
          fan_id: string
          id?: string
          reason: string
          resolved?: boolean
          severity?: Database["public"]["Enums"]["risk_severity"]
        }
        Update: {
          created_at?: string
          fan_id?: string
          id?: string
          reason?: string
          resolved?: boolean
          severity?: Database["public"]["Enums"]["risk_severity"]
        }
        Relationships: [
          {
            foreignKeyName: "risk_flags_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      risk_settings: {
        Row: {
          description: string | null
          id: string
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          description?: string | null
          id?: string
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          description?: string | null
          id?: string
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      scan_events: {
        Row: {
          code_hash: string
          created_at: string
          device: string | null
          id: string
          latitude: number | null
          longitude: number | null
          result: Database["public"]["Enums"]["scan_result"]
          staff_id: string
        }
        Insert: {
          code_hash: string
          created_at?: string
          device?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          result: Database["public"]["Enums"]["scan_result"]
          staff_id: string
        }
        Update: {
          code_hash?: string
          created_at?: string
          device?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          result?: Database["public"]["Enums"]["scan_result"]
          staff_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "scan_events_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff_members"
            referencedColumns: ["user_id"]
          },
        ]
      }
      segments: {
        Row: {
          created_at: string
          filters: Json
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          filters?: Json
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          filters?: Json
          id?: string
          name?: string
        }
        Relationships: []
      }
      site_announcements: {
        Row: {
          created_at: string
          ends_at: string | null
          id: string
          is_published: boolean
          link_url: string | null
          message: string
          starts_at: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          id?: string
          is_published?: boolean
          link_url?: string | null
          message: string
          starts_at?: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          id?: string
          is_published?: boolean
          link_url?: string | null
          message?: string
          starts_at?: string
        }
        Relationships: []
      }
      site_stats: {
        Row: {
          created_at: string
          id: string
          is_published: boolean
          is_sponsor: boolean
          label: string
          logo_url: string | null
          note: string | null
          order_index: number
          value: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_published?: boolean
          is_sponsor?: boolean
          label: string
          logo_url?: string | null
          note?: string | null
          order_index?: number
          value: string
        }
        Update: {
          created_at?: string
          id?: string
          is_published?: boolean
          is_sponsor?: boolean
          label?: string
          logo_url?: string | null
          note?: string | null
          order_index?: number
          value?: string
        }
        Relationships: []
      }
      site_team_members: {
        Row: {
          created_at: string
          group_category: string
          id: string
          is_published: boolean
          name: string
          order_index: number
          photo_url: string | null
          role: string
        }
        Insert: {
          created_at?: string
          group_category: string
          id?: string
          is_published?: boolean
          name: string
          order_index?: number
          photo_url?: string | null
          role: string
        }
        Update: {
          created_at?: string
          group_category?: string
          id?: string
          is_published?: boolean
          name?: string
          order_index?: number
          photo_url?: string | null
          role?: string
        }
        Relationships: []
      }
      social_links: {
        Row: {
          created_at: string
          icon: string | null
          id: string
          is_published: boolean
          label: string
          order_index: number
          platform: string
          url: string
        }
        Insert: {
          created_at?: string
          icon?: string | null
          id?: string
          is_published?: boolean
          label: string
          order_index?: number
          platform: string
          url: string
        }
        Update: {
          created_at?: string
          icon?: string | null
          id?: string
          is_published?: boolean
          label?: string
          order_index?: number
          platform?: string
          url?: string
        }
        Relationships: []
      }
      sponsor_videos: {
        Row: {
          created_at: string
          cta_text: string
          drive_file_id: string
          id: string
          is_active: boolean
          min_seconds: number
          order_index: number
          redirect_url: string | null
          reward_points: number
          sponsor_name: string | null
          title: string
          updated_at: string
          video_url: string
        }
        Insert: {
          created_at?: string
          cta_text?: string
          drive_file_id: string
          id?: string
          is_active?: boolean
          min_seconds?: number
          order_index?: number
          redirect_url?: string | null
          reward_points?: number
          sponsor_name?: string | null
          title: string
          updated_at?: string
          video_url: string
        }
        Update: {
          created_at?: string
          cta_text?: string
          drive_file_id?: string
          id?: string
          is_active?: boolean
          min_seconds?: number
          order_index?: number
          redirect_url?: string | null
          reward_points?: number
          sponsor_name?: string | null
          title?: string
          updated_at?: string
          video_url?: string
        }
        Relationships: []
      }
      staff_members: {
        Row: {
          active: boolean
          created_at: string
          role: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          role?: Database["public"]["Enums"]["staff_role"]
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          role?: Database["public"]["Enums"]["staff_role"]
          user_id?: string
        }
        Relationships: []
      }
      standings: {
        Row: {
          created_at: string
          games_played: number
          id: string
          logo_url: string | null
          losses: number
          order_index: number
          points: number
          team_name: string
          wins: number
        }
        Insert: {
          created_at?: string
          games_played?: number
          id?: string
          logo_url?: string | null
          losses?: number
          order_index?: number
          points?: number
          team_name: string
          wins?: number
        }
        Update: {
          created_at?: string
          games_played?: number
          id?: string
          logo_url?: string | null
          losses?: number
          order_index?: number
          points?: number
          team_name?: string
          wins?: number
        }
        Relationships: []
      }
      system_alerts: {
        Row: {
          alert_type: string
          created_at: string
          id: string
          message: string
          metadata: Json | null
          resolved: boolean
          resolved_at: string | null
          resolved_by: string | null
          severity: string
        }
        Insert: {
          alert_type: string
          created_at?: string
          id?: string
          message: string
          metadata?: Json | null
          resolved?: boolean
          resolved_at?: string | null
          resolved_by?: string | null
          severity: string
        }
        Update: {
          alert_type?: string
          created_at?: string
          id?: string
          message?: string
          metadata?: Json | null
          resolved?: boolean
          resolved_at?: string | null
          resolved_by?: string | null
          severity?: string
        }
        Relationships: [
          {
            foreignKeyName: "system_alerts_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_attempts: {
        Row: {
          answers: Json | null
          expires_at: string
          fan_id: string
          id: string
          idempotency_key: string
          pearls_awarded: number
          score: number
          seed: number
          started_at: string
          submitted_at: string | null
          suspicious: boolean
          trivia_id: string
        }
        Insert: {
          answers?: Json | null
          expires_at: string
          fan_id: string
          id?: string
          idempotency_key: string
          pearls_awarded?: number
          score?: number
          seed?: number
          started_at?: string
          submitted_at?: string | null
          suspicious?: boolean
          trivia_id: string
        }
        Update: {
          answers?: Json | null
          expires_at?: string
          fan_id?: string
          id?: string
          idempotency_key?: string
          pearls_awarded?: number
          score?: number
          seed?: number
          started_at?: string
          submitted_at?: string | null
          suspicious?: boolean
          trivia_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_attempts_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trivia_attempts_trivia_id_fkey"
            columns: ["trivia_id"]
            isOneToOne: false
            referencedRelation: "trivias"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_options: {
        Row: {
          id: string
          is_correct: boolean
          option_text: string
          question_id: string
        }
        Insert: {
          id?: string
          is_correct?: boolean
          option_text: string
          question_id: string
        }
        Update: {
          id?: string
          is_correct?: boolean
          option_text?: string
          question_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_options_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "trivia_questions"
            referencedColumns: ["id"]
          },
        ]
      }
      trivia_questions: {
        Row: {
          created_at: string
          id: string
          order_index: number
          points: number
          question_text: string
          trivia_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          order_index?: number
          points?: number
          question_text: string
          trivia_id: string
        }
        Update: {
          created_at?: string
          id?: string
          order_index?: number
          points?: number
          question_text?: string
          trivia_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivia_questions_trivia_id_fkey"
            columns: ["trivia_id"]
            isOneToOne: false
            referencedRelation: "trivias"
            referencedColumns: ["id"]
          },
        ]
      }
      trivias: {
        Row: {
          created_at: string
          description: string | null
          ends_at: string
          id: string
          max_attempts: number
          reward_rules: Json
          starts_at: string
          status: Database["public"]["Enums"]["trivia_status"]
          target_segment_id: string | null
          time_limit_seconds: number
          title: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          ends_at: string
          id?: string
          max_attempts?: number
          reward_rules?: Json
          starts_at: string
          status?: Database["public"]["Enums"]["trivia_status"]
          target_segment_id?: string | null
          time_limit_seconds?: number
          title: string
        }
        Update: {
          created_at?: string
          description?: string | null
          ends_at?: string
          id?: string
          max_attempts?: number
          reward_rules?: Json
          starts_at?: string
          status?: Database["public"]["Enums"]["trivia_status"]
          target_segment_id?: string | null
          time_limit_seconds?: number
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "trivias_target_segment_id_fkey"
            columns: ["target_segment_id"]
            isOneToOne: false
            referencedRelation: "segments"
            referencedColumns: ["id"]
          },
        ]
      }
      wallets: {
        Row: {
          balance_cache: number
          fan_id: string
          updated_at: string
        }
        Insert: {
          balance_cache?: number
          fan_id: string
          updated_at?: string
        }
        Update: {
          balance_cache?: number
          fan_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallets_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      mv_daily_economy_stats: {
        Row: {
          entry_date: string | null
          pearls_held: number | null
          pearls_issued: number | null
          pearls_spent: number | null
        }
        Relationships: []
      }
      mv_daily_fan_activity: {
        Row: {
          activity_date: string | null
          fan_id: string | null
          pearls_earned: number | null
          trivias_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "trivia_attempts_fan_id_fkey"
            columns: ["fan_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      mv_demographics: {
        Row: {
          age_group: string | null
          fan_count: number | null
          gender: string | null
          municipality: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      accept_terms: { Args: never; Returns: Json }
      activate_landing_cta: { Args: { p_id: string }; Returns: undefined }
      adjust_stock: {
        Args: { p_delta: number; p_product_id: string; p_reason: string }
        Returns: Json
      }
      admin_adjust_pearls: {
        Args: { p_amount: number; p_fan_id: string; p_reason: string }
        Returns: Json
      }
      admin_archive_trivia: { Args: { p_trivia_id: string }; Returns: Json }
      admin_delete_game: { Args: { p_game_id: string }; Returns: Json }
      admin_delete_login_modal_slide: {
        Args: { p_slide_id: string }
        Returns: Json
      }
      admin_delete_player: { Args: { p_player_id: string }; Returns: Json }
      admin_duplicate_trivia: { Args: { p_trivia_id: string }; Returns: Json }
      admin_get_fan: { Args: { p_fan_id: string }; Returns: Json }
      admin_get_trivia_with_options: {
        Args: { p_trivia_id: string }
        Returns: Json
      }
      admin_list_fans: {
        Args: {
          p_age_max?: number
          p_age_min?: number
          p_cursor?: string
          p_favorite_player_id?: string
          p_inactive_days?: number
          p_limit?: number
          p_municipality?: string
          p_search?: string
          p_status?: Database["public"]["Enums"]["user_status"]
        }
        Returns: Json
      }
      admin_publish_policy: {
        Args: { p_content: string; p_slug: string; p_version: string }
        Returns: Json
      }
      admin_publish_trivia: { Args: { p_trivia_id: string }; Returns: Json }
      admin_reactivate_fan: {
        Args: { p_fan_id: string; p_reason: string }
        Returns: Json
      }
      admin_release_held_pearls: {
        Args: { p_ledger_id: string; p_note: string }
        Returns: Json
      }
      admin_reorder_login_modal_slides: {
        Args: { p_slide_ids: string[] }
        Returns: Json
      }
      admin_resolve_redemption_issue: {
        Args: { p_action: string; p_note: string; p_redemption_id: string }
        Returns: Json
      }
      admin_resolve_risk_flag: {
        Args: { p_flag_id: string; p_note: string }
        Returns: Json
      }
      admin_revoke_held_pearls: {
        Args: { p_ledger_id: string; p_note: string }
        Returns: Json
      }
      admin_risk_queue: { Args: { p_resolved?: boolean }; Returns: Json }
      admin_suspend_fan: {
        Args: { p_fan_id: string; p_reason: string }
        Returns: Json
      }
      admin_toggle_staff_active: {
        Args: { p_active: boolean; p_target_id: string }
        Returns: Json
      }
      admin_update_ads_settings: { Args: { p_settings: Json }; Returns: Json }
      admin_update_birth_date: {
        Args: { p_birth_date: string; p_reason: string; p_user_id: string }
        Returns: Json
      }
      admin_update_economy_settings: {
        Args: { p_settings: Json }
        Returns: Json
      }
      admin_update_staff_role: {
        Args: {
          p_new_role: Database["public"]["Enums"]["staff_role"]
          p_target_id: string
        }
        Returns: Json
      }
      admin_upsert_game: { Args: { p_game: Json }; Returns: Json }
      admin_upsert_login_modal_slide: {
        Args: {
          p_cta_label: string
          p_cta_url: string
          p_ends_at: string
          p_id: string
          p_image_url: string
          p_position: number
          p_starts_at: string
          p_status: string
          p_subtitle: string
          p_title: string
        }
        Returns: Json
      }
      admin_upsert_player: { Args: { p_player: Json }; Returns: Json }
      admin_upsert_product: { Args: { p_product: Json }; Returns: Json }
      admin_upsert_segment: { Args: { p_segment: Json }; Returns: Json }
      admin_upsert_trivia: {
        Args: { p_questions?: Json; p_trivia: Json }
        Returns: Json
      }
      analytics_active_users: {
        Args: {
          p_end_date?: string
          p_granularity?: string
          p_start_date?: string
        }
        Returns: Json
      }
      analytics_ads: { Args: { p_from?: string; p_to?: string }; Returns: Json }
      analytics_demographics: { Args: never; Returns: Json }
      analytics_economy: { Args: never; Returns: Json }
      analytics_engagement_hours: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_funnel: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_overview: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_products: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      analytics_top_fans: {
        Args: { p_end_date?: string; p_limit?: number; p_start_date?: string }
        Returns: Json
      }
      analytics_trivias: {
        Args: { p_end_date?: string; p_start_date?: string }
        Returns: Json
      }
      approve_redemption: {
        Args: { p_note?: string; p_redemption_id: string }
        Returns: Json
      }
      assert_active_verified_fan:
        | { Args: never; Returns: string }
        | { Args: { p_user_id: string }; Returns: string }
      assert_admin: { Args: never; Returns: boolean }
      assert_staff: { Args: never; Returns: boolean }
      audit_search: {
        Args: {
          p_action?: string
          p_actor_id?: string
          p_cursor?: string
          p_entity?: string
          p_from?: string
          p_limit?: number
          p_to?: string
        }
        Returns: Json
      }
      calculate_and_apply_streak_bonus: {
        Args: { p_fan_id: string }
        Returns: Json
      }
      cancel_ad_session: {
        Args: { p_reason: string; p_session_id: string }
        Returns: Json
      }
      cancel_redemption: {
        Args: { p_reason?: string; p_redemption_id: string }
        Returns: Json
      }
      check_email_exists: { Args: { p_email: string }; Returns: boolean }
      check_in_redemption: {
        Args: {
          p_idempotency_key: string
          p_note?: string
          p_redemption_id: string
        }
        Returns: Json
      }
      check_rate_limit: {
        Args: {
          p_action: string
          p_max: number
          p_user_id: string
          p_window_seconds: number
        }
        Returns: undefined
      }
      claim_birthday_bonus: { Args: never; Returns: Json }
      claim_video_points: { Args: { p_video_id: string }; Returns: Json }
      clean_test_records: { Args: never; Returns: undefined }
      complete_ad_session: {
        Args: { p_idempotency_key: string; p_session_id: string }
        Returns: Json
      }
      compute_redemption_code_hash: {
        Args: { p_code_or_hash: string }
        Returns: string
      }
      compute_risk: { Args: { p_fan_id: string }; Returns: undefined }
      confirm_test_user_email: { Args: { p_email: string }; Returns: undefined }
      create_notification: {
        Args: {
          p_body: string
          p_data?: Json
          p_dedup_key?: string
          p_title: string
          p_type: string
          p_user_id: string
        }
        Returns: string
      }
      create_security_notification: {
        Args: { p_body: string; p_title: string; p_user_id: string }
        Returns: undefined
      }
      cron_cleanup_old_notifications: { Args: never; Returns: undefined }
      cron_notify_expiring_redemptions: { Args: never; Returns: undefined }
      cron_notify_match_day: { Args: never; Returns: undefined }
      cron_notify_new_trivias: { Args: never; Returns: undefined }
      delete_my_account: { Args: never; Returns: Json }
      deliver_redemption:
        | { Args: { p_code: string; p_note?: string }; Returns: Json }
        | {
            Args: {
              p_idempotency_key: string
              p_note?: string
              p_redemption_id: string
            }
            Returns: Json
          }
      enqueue_birthday_notifications: {
        Args: { p_now?: string }
        Returns: Json
      }
      ensure_profile: { Args: never; Returns: Json }
      generate_redemption_code: {
        Args: { p_redemption_id: string }
        Returns: string
      }
      get_active_legal_versions: { Args: never; Returns: Json }
      get_ads_progress: { Args: never; Returns: Json }
      get_attempt_questions: { Args: { p_attempt_id: string }; Returns: Json }
      get_birthday_card: { Args: never; Returns: Json }
      get_daily_video_progress: { Args: never; Returns: Json }
      get_leaderboard: { Args: { p_period?: string }; Returns: Json }
      get_login_modal: { Args: never; Returns: Json }
      get_redemption_qr: { Args: { p_redemption_id: string }; Returns: Json }
      get_streak_info: { Args: { p_fan_id: string }; Returns: Json }
      health_check: { Args: never; Returns: Json }
      helper_generate_code_with_key: {
        Args: { p_key_id: string; p_redemption_id: string }
        Returns: string
      }
      home_summary: { Args: never; Returns: Json }
      import_ad_report: {
        Args: { p_day: string; p_impressions: number; p_notes?: string }
        Returns: Json
      }
      is_admin: { Args: { user_id: string }; Returns: boolean }
      is_admin_check: { Args: never; Returns: boolean }
      is_staff_or_admin: { Args: { user_id: string }; Returns: boolean }
      mark_all_notifications_read: { Args: never; Returns: Json }
      mark_notification_read: {
        Args: { p_notification_id: string }
        Returns: Json
      }
      parse_instagram_shortcode: { Args: { p_url: string }; Returns: string }
      purge_auth_identities: { Args: { p_user_id: string }; Returns: Json }
      purge_fraud_telemetry: { Args: never; Returns: undefined }
      reconcile_wallets: {
        Args: never
        Returns: {
          balance_cache: number
          computed_balance: number
          difference: number
          fan_id: string
        }[]
      }
      redeem_product: {
        Args: {
          p_idempotency_key: string
          p_product_id: string
          p_variant: string
        }
        Returns: Json
      }
      refresh_analytics_materialized_views: { Args: never; Returns: undefined }
      register_email_send_attempt: { Args: never; Returns: Json }
      register_push_subscription: {
        Args: {
          p_auth: string
          p_endpoint: string
          p_p256dh: string
          p_user_agent?: string
        }
        Returns: Json
      }
      reject_redemption: {
        Args: { p_reason: string; p_redemption_id: string }
        Returns: Json
      }
      report_redemption_issue:
        | { Args: { p_reason: string; p_redemption_id: string }; Returns: Json }
        | {
            Args: { p_note?: string; p_reason: string; p_redemption_id: string }
            Returns: Json
          }
      run_daily_wallet_reconciliation: { Args: never; Returns: undefined }
      save_mfa_recovery_code_hashes: {
        Args: { p_hashes: string[] }
        Returns: Json
      }
      seed_analytics_performance_data: {
        Args: { p_num_fans?: number; p_num_ledger?: number }
        Returns: Json
      }
      segment_count: { Args: { p_segment_id: string }; Returns: number }
      segment_members: {
        Args: { p_cursor?: string; p_limit?: number; p_segment_id: string }
        Returns: Json
      }
      send_test_birthday_notification: { Args: never; Returns: Json }
      set_birth_date: { Args: { p_birth_date: string }; Returns: Json }
      staff_redemption_queue: {
        Args: {
          p_cursor?: string
          p_limit?: number
          p_search?: string
          p_status?: string
        }
        Returns: {
          cost_pearls: number
          created_at: string
          delivered_at: string
          expires_at: string
          fan_avatar_url: string
          fan_display_name: string
          fan_id: string
          id: string
          product_category: Database["public"]["Enums"]["product_category"]
          product_id: string
          product_name: string
          status: Database["public"]["Enums"]["redemption_status"]
          variant: string
        }[]
      }
      staff_search_fans: {
        Args: { p_limit?: number; p_query: string }
        Returns: {
          avatar_url: string
          display_name: string
          id: string
          last_5_redemptions: Json
          pearl_balance: number
          status: string
        }[]
      }
      staff_upsert_product: { Args: { p_product: Json }; Returns: Json }
      staff_upsert_trivia:
        | { Args: { p_trivia: Json }; Returns: Json }
        | { Args: { p_questions?: Json; p_trivia: Json }; Returns: Json }
      start_ad_session: { Args: { p_idempotency_key?: string }; Returns: Json }
      start_trivia_attempt: {
        Args: { p_idempotency_key: string; p_trivia_id: string }
        Returns: Json
      }
      submit_trivia_attempt: {
        Args: {
          p_answers: Json
          p_attempt_id: string
          p_idempotency_key: string
        }
        Returns: Json
      }
      unregister_push_subscription: {
        Args: { p_endpoint: string }
        Returns: Json
      }
      update_birth_date: { Args: { p_birth_date: string }; Returns: Json }
      update_birthday_settings: {
        Args: {
          p_bonus_pearls: number
          p_enabled: boolean
          p_grace_days: number
          p_image_url: string
          p_message: string
          p_send_hour: number
          p_title: string
        }
        Returns: Json
      }
      update_display_name: { Args: { p_display_name: string }; Returns: Json }
      user_has_verified_mfa: { Args: { p_uid: string }; Returns: boolean }
      validate_crockford_base32_checksum: {
        Args: { p_code: string }
        Returns: boolean
      }
      validate_login_modal_urls: {
        Args: { p_cta_url: string; p_image_url: string }
        Returns: undefined
      }
      verify_redemption_code: {
        Args: { p_code: string; p_device?: string }
        Returns: Json
      }
      wallet_ledger: {
        Args: { p_cursor?: string; p_limit?: number; p_type?: string }
        Returns: Json
      }
      wallet_summary: { Args: never; Returns: Json }
    }
    Enums: {
      game_status: "scheduled" | "live" | "finished" | "cancelled"
      ledger_status: "confirmed" | "held" | "revoked"
      ledger_type:
        | "trivia_reward"
        | "redemption"
        | "refund"
        | "admin_adjustment"
        | "bonus"
        | "streak_bonus"
        | "birthday_bonus"
        | "ad_reward"
      product_category: "physical" | "experience" | "raffle"
      redemption_status:
        | "pending"
        | "approved"
        | "scheduled"
        | "delivered"
        | "completed"
        | "cancelled"
        | "rejected"
        | "issue"
        | "expired"
      risk_severity: "low" | "medium" | "high"
      scan_result: "success" | "invalid" | "already_delivered" | "expired"
      staff_role: "staff" | "admin"
      trivia_status: "draft" | "published" | "archived"
      user_status: "active" | "suspended" | "deleted"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      game_status: ["scheduled", "live", "finished", "cancelled"],
      ledger_status: ["confirmed", "held", "revoked"],
      ledger_type: [
        "trivia_reward",
        "redemption",
        "refund",
        "admin_adjustment",
        "bonus",
        "streak_bonus",
        "birthday_bonus",
        "ad_reward",
      ],
      product_category: ["physical", "experience", "raffle"],
      redemption_status: [
        "pending",
        "approved",
        "scheduled",
        "delivered",
        "completed",
        "cancelled",
        "rejected",
        "issue",
        "expired",
      ],
      risk_severity: ["low", "medium", "high"],
      scan_result: ["success", "invalid", "already_delivered", "expired"],
      staff_role: ["staff", "admin"],
      trivia_status: ["draft", "published", "archived"],
      user_status: ["active", "suspended", "deleted"],
    },
  },
} as const
