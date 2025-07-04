import 'dart:async';
import 'dart:convert';

import 'package:azul_envato_checker/azul_envato_checker.dart';
import 'package:filling_slider/filling_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';


import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:volume_controller/volume_controller.dart';

//import 'package:wakelock/wakelock.dart';

import '../../helpers/helpers.dart';
import '../../logic/blocs/auth/auth_bloc.dart';
import '../../logic/blocs/categories/channels/channels_bloc.dart';
import '../../logic/blocs/categories/live_caty/live_caty_bloc.dart';
import '../../logic/blocs/categories/movie_caty/movie_caty_bloc.dart';
import '../../logic/blocs/categories/series_caty/series_caty_bloc.dart';
import '../../logic/cubits/favorites/favorites_cubit.dart';
import '../../logic/cubits/settings/settings_cubit.dart';
import '../../logic/cubits/video/video_cubit.dart';
import '../../logic/cubits/watch/watching_cubit.dart';
import '../../repository/api/api.dart';
import '../../repository/locale/admob.dart';
import '../../repository/models/category.dart';
import '../../repository/models/channel_live.dart';
import '../../repository/models/channel_movie.dart';
import '../../repository/models/channel_serie.dart';
import '../../repository/models/epg.dart';
import '../../repository/models/movie_detail.dart';
import '../../repository/models/serie_details.dart';
import '../../repository/models/user.dart';
import '../../repository/models/watching.dart';
import '../widgets/widgets.dart';

part 'live/live_categories.dart';
part 'live/live_channels.dart';
part 'movie/movie_categories.dart';
part 'movie/movie_channels.dart';
part 'movie/movie_details.dart';
part 'player/full_video.dart';
part 'player/player_video.dart';
part 'series/serie_details.dart';
part 'series/serie_seasons.dart';
part 'series/series_categories.dart';
part 'series/series_channels.dart';
part 'user/demo.dart';
part 'user/register.dart';
part 'user/register_tv.dart';
part 'user/settings.dart';
part 'user/splash.dart';
part 'user/intro.dart';
part 'user/favourites.dart';
part 'welcome.dart';
part 'user/catch_up.dart';
