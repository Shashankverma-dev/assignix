import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../config/supabaseClient';

const AuthContext = createContext();

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const fetchUserProfile = useCallback(async (userId, forceLoading = false) => {
    if (forceLoading) setLoading(true);
    try {
      // Use a single join query to fetch profile, friends, and pending requests
      const { data: profile, error: profileError } = await supabase
        .from('users')
        .select(`
          *,
          friendships:friendships!friendships_user_id_fkey(
            friend:users!friendships_friend_id_fkey(id, name, username, avatar, role, xp, streak)
          ),
          sent_requests:friend_requests!friend_requests_from_id_fkey(
            *,
            sender:users!friend_requests_from_id_fkey(id, name, username, avatar),
            receiver:users!friend_requests_to_id_fkey(id, name, username, avatar)
          ),
          received_requests:friend_requests!friend_requests_to_id_fkey(
            *,
            sender:users!friend_requests_from_id_fkey(id, name, username, avatar),
            receiver:users!friend_requests_to_id_fkey(id, name, username, avatar)
          )
        `)
        .eq('id', userId)
        .eq('sent_requests.status', 'pending')
        .eq('received_requests.status', 'pending')
        .single();
        
      if (profileError && profileError.code !== 'PGRST116') {
        throw profileError;
      }

      // Process friends from the join result
      const detailedFriends = profile?.friendships?.map(f => f.friend).filter(Boolean) || [];

      // Process and merge pending requests (both incoming and outgoing)
      const requests = [
        ...(profile?.sent_requests || []),
        ...(profile?.received_requests || [])
      ];
      
      const userData = profile ? { 
        ...profile, 
        id: userId, 
        friends: detailedFriends,
        friendRequests: requests,
        notifications: [] // Will be fetched separately
      } : { 
        id: userId, 
        role: 'student', 
        friends: [], 
        friendRequests: [],
        notifications: []
      };

      setUser(userData);
      // We don't call fetchNotifications here directly to keep this stable, 
      // but the useEffect will handle initial load
    } catch (error) {
      console.error('Error fetching user profile:', error);
      if (userId) {
        setUser(prev => prev || { id: userId, friends: [], friendRequests: [], notifications: [] });
      }
    } finally {
      setLoading(false);
    }
  }, []); // Stable reference



  const login = useCallback(async (email, password) => {
    try {
      const { data: authData, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) return { success: false, message: error.message };
      
      // Fetch profile to get role for immediate redirection
      const { data: profile } = await supabase
        .from('users')
        .select('*')
        .eq('id', authData.user.id)
        .single();
        
      const fullUser = { ...profile, ...authData.user, role: profile?.role || 'student' };
      setUser(fullUser); // Force immediate state update
      setLoading(false);
      return { success: true, user: fullUser };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }, []);

  const loginWithGoogle = useCallback(async (role = 'student') => {
    try {
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/dashboard`,
          data: {
            role
          }
        }
      });
      if (error) return { success: false, message: error.message };
      return { success: true, data };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }, []);

  const register = useCallback(async (name, username, email, password, role = 'student') => {
    try {
      // 1. Check if username is already taken
      const { data: existingUser, error: checkError } = await supabase
        .from('users')
        .select('username')
        .eq('username', username)
        .maybeSingle();

      if (checkError) return { success: false, message: 'Error checking username availability' };
      if (existingUser) return { success: false, message: 'Username is already taken' };

      // 2. Sign up with metadata for the trigger
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            name,
            username,
            role
          }
        }
      });
      
      if (error) return { success: false, message: error.message };
      return { success: true };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }, []);

  const logout = useCallback(async () => {
    await supabase.auth.signOut();
    setUser(null);
    navigate('/login');
  }, [navigate]);

  const updateProfile = useCallback(async (updateData) => {
    if (!user) return { success: false, message: 'Not logged in' };
    try {
      const { error } = await supabase
        .from('users')
        .update(updateData)
        .eq('id', user.id);
        
      if (error) return { success: false, message: error.message };
      
      setUser(prev => ({ ...prev, ...updateData }));
      return { success: true };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }, [user]);

  const refreshUser = useCallback(async (newData = null) => {
    if (newData) {
      setUser(prev => prev ? { ...prev, ...newData } : prev);
    } else if (user?.id) {
      await fetchUserProfile(user.id);
    }
  }, [user?.id, fetchUserProfile]);

  // Friend System Logic
  const sendFriendRequest = useCallback(async (friendId) => {
     if (!user?.id) return { success: false };
     const { error } = await supabase
       .from('friend_requests')
       .insert({ from_id: user.id, to_id: friendId, status: 'pending' });
     if (error) console.error('Friend Request Error:', error);
     return error ? { success: false, message: error.message } : { success: true, message: 'Request sent' };
  }, [user?.id]);

  const acceptFriendRequest = useCallback(async (requestId) => {
      try {
        // Now handled by database trigger tr_handle_friend_request_acceptance
        const { error } = await supabase
          .from('friend_requests')
          .update({ status: 'accepted' })
          .eq('id', requestId);
        
        if (error) throw error;

        await fetchUserProfile(user.id);
        return { success: true, message: 'Friend request accepted' };
      } catch (error) {
        return { success: false, message: error.message };
      }
  }, [user?.id, fetchUserProfile]);

  const rejectFriendRequest = useCallback(async (requestId) => {
      if (!user?.id) return { success: false };
      const { error } = await supabase.from('friend_requests').delete().eq('id', requestId);
      if (error) return { success: false, message: error.message };
      await fetchUserProfile(user.id);
      return { success: true, message: 'Friend request rejected' };
  }, [user?.id, fetchUserProfile]);

  const removeFriend = useCallback(async (friendId) => {
      if (!user?.id) return { success: false };
      try {
        // Both friendships (A->B and B->A) and the 'friends' arrays are cleaned up
        // automatically by the database trigger 'on_friendship_deleted'.
        const { error } = await supabase
          .from('friendships')
          .delete()
          .match({ user_id: user.id, friend_id: friendId });

        if (error) throw error;

        // Also delete the reverse row to be thorough (since we insert both ways)
        await supabase
          .from('friendships')
          .delete()
          .match({ user_id: friendId, friend_id: user.id });

        await fetchUserProfile(user.id);
        return { success: true, message: 'Friend removed' };
      } catch (error) {
        return { success: false, message: error.message };
      }
  }, [user?.id, fetchUserProfile]);

  const fetchNotifications = useCallback(async (userIdOverride) => {
     const targetId = userIdOverride || user?.id;
     if (!targetId) return;
     
     try {
       const { data, error } = await supabase
         .from('notifications')
         .select('*')
         .eq('user_id', targetId)
         .order('created_at', { ascending: false });
       
       if (!error && data) {
         const formattedNotifs = data.map(n => ({
           ...n,
           time: new Date(n.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
           date: new Date(n.created_at).toLocaleDateString()
         }));
         setUser(prev => prev ? ({ ...prev, notifications: formattedNotifs }) : prev);
       }
     } catch (err) {
       console.error('Error fetching notifications:', err);
     }
  }, [user?.id]);

  const markAllNotificationsRead = useCallback(async () => {
     if (!user) return;
     const { error } = await supabase.from('notifications').update({ read: true }).eq('user_id', user.id);
     if (!error) fetchNotifications();
  }, [user, fetchNotifications]);

  useEffect(() => {
    // Check active sessions and sets the user
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        fetchUserProfile(session.user.id, true);
      } else {
        setLoading(false);
      }
    });

    // Listen for changes on auth state
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        fetchUserProfile(session.user.id);
      } else {
        setUser(null);
        setLoading(false);
      }
    });

    // Real-time subscriptions
    let requestChannel;
    let notifChannel;

    if (user?.id) {
      requestChannel = supabase
        .channel(`friend_requests_${user.id}`)
        .on('postgres_changes', { 
          event: '*', 
          schema: 'public', 
          table: 'friend_requests',
          filter: `to_id=eq.${user.id}`
        }, () => fetchUserProfile(user.id))
        .on('postgres_changes', { 
          event: '*', 
          schema: 'public', 
          table: 'friend_requests',
          filter: `from_id=eq.${user.id}`
        }, () => fetchUserProfile(user.id))
        .subscribe();

      notifChannel = supabase
        .channel(`notifications_${user.id}`)
        .on('postgres_changes', { 
          event: 'INSERT', 
          schema: 'public', 
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        }, () => fetchNotifications())
        .subscribe();
    }

    return () => {
      subscription.unsubscribe();
      if (requestChannel) supabase.removeChannel(requestChannel);
      if (notifChannel) supabase.removeChannel(notifChannel);
    };
  }, [user?.id, fetchUserProfile, fetchNotifications]);

  return (
    <AuthContext.Provider value={{ 
      user, 
      login, 
      loginWithGoogle,
      register, 
      logout, 
      updateProfile,
      refreshUser,
      sendFriendRequest,
      acceptFriendRequest,
      rejectFriendRequest,
      removeFriend,
      fetchNotifications,
      markAllNotificationsRead,
      loading,
      friends: user?.friends || [],
      notifications: user?.notifications || []
    }}>
      {!loading && children}
    </AuthContext.Provider>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthContext)
