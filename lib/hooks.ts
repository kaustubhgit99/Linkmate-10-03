'use client'
import { useState, useEffect, useCallback } from 'react'
import { getSupabase } from './supabase'
import type { User } from '@supabase/supabase-js'

export type UserProfile = {
  id: string
  email: string
  full_name: string | null
  role: 'citizen' | 'owner' | 'admin'
  phone: string | null
  avatar_url: string | null
}

export function useAuth() {
  const [user, setUser] = useState<User | null>(null)
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchProfile = useCallback(async (uid: string) => {
    const supabase = getSupabase()
    const { data } = await supabase.from('users').select('*').eq('id', uid).single()
    if (data) setProfile(data as UserProfile)
    setLoading(false)
  }, [])

  useEffect(() => {
    const supabase = getSupabase()

    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
      if (session?.user) {
        fetchProfile(session.user.id)
      } else {
        setLoading(false)
      }
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
      if (session?.user) {
        fetchProfile(session.user.id)
      } else {
        setProfile(null)
        setLoading(false)
      }
    })

    return () => subscription.unsubscribe()
  }, [fetchProfile])

  const signOut = async () => {
    const supabase = getSupabase()
    await supabase.auth.signOut()
  }

  return { user, profile, loading, signOut }
}

export function useFavorites(userId?: string) {
  const [favorites, setFavorites] = useState<string[]>([])

  useEffect(() => {
    if (!userId) return
    const supabase = getSupabase()
    supabase
      .from('favorites')
      .select('room_id')
      .eq('user_id', userId)
      .then(({ data }) => {
        if (data) setFavorites(data.map((f: { room_id: string }) => f.room_id))
      })
  }, [userId])

  const toggleFavorite = async (roomId: string) => {
    if (!userId) return
    const supabase = getSupabase()
    if (favorites.includes(roomId)) {
      await supabase.from('favorites').delete().eq('user_id', userId).eq('room_id', roomId)
      setFavorites(prev => prev.filter(id => id !== roomId))
    } else {
      await supabase.from('favorites').insert({ user_id: userId, room_id: roomId })
      setFavorites(prev => [...prev, roomId])
    }
  }

  return { favorites, toggleFavorite }
}
