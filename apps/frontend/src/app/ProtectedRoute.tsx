import { ReactNode, useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { LoadingState } from '../components/feedback/LoadingState';
import { UnauthorizedState } from '../components/feedback/UnauthorizedState';
import { meRequest } from '../services/auth.service';
import { useAuthStore } from '../stores/auth.store';

type ProtectedRouteProps = {
  children: ReactNode;
};

type RouteState = 'loading' | 'authorized' | 'unauthorized';

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);
  const setSession = useAuthStore((state) => state.setSession);
  const clearSession = useAuthStore((state) => state.clearSession);
  const [routeState, setRouteState] = useState<RouteState>('loading');

  useEffect(() => {
    async function validateSession() {
      const token = accessToken || loadToken();

      if (!token) {
        setRouteState('unauthorized');
        return;
      }

      try {
        const response = await meRequest(token);

        if (!response.success) {
          clearSession();
          setRouteState('unauthorized');
          return;
        }

        setSession(response.data.user, token);
        setRouteState('authorized');
      } catch (_error) {
        clearSession();
        setRouteState('unauthorized');
      }
    }

    void validateSession();
  }, [accessToken, clearSession, loadToken, setSession]);

  if (routeState === 'loading') {
    return <LoadingState message="Validando sessao..." />;
  }

  if (routeState === 'unauthorized') {
    if (!accessToken && !loadToken()) {
      return <Navigate to="/login" replace />;
    }

    return <UnauthorizedState />;
  }

  return <>{children}</>;
}
